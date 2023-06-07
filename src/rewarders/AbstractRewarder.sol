// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";

import { IStakeTracking } from "../interfaces/rewarders/IStakeTracking.sol";
import { IBaseRewarder } from "../interfaces/rewarders/IBaseRewarder.sol";

import { IGPToke } from "src/interfaces/staking/IGPToke.sol";

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";

/**
 * @dev An abstract contract that serves as the base for rewarder contracts.
 * It implements common functionalities for reward distribution, including calculating rewards per token,
 * tracking user rewards, and handling stake-related operations.
 * Inherited by rewarder contracts, such as MainRewarder and ExtraRewarder.
 * The contract is inspired by the Convex contract but uses block-based duration instead of timestamp-based duration.
 * Unlike Convex, it does not own the LP token but it interacts with an external LP token contract.
 */
abstract contract AbstractRewarder is IBaseRewarder, SecurityBase {
    using SafeERC20 for IERC20;

    /**
     * @dev The duration of the reward period in blocks.
     */
    uint256 public durationInBlock;

    /**
     * @dev It is used to determine if the new rewards should be distributed immediately or queued for later.
     *  If the ratio of current rewards to the sum of new and queued rewards is less than newRewardRatio,
     *  the new rewards are distributed immediately; otherwise, they are added to the queue.
     */
    uint256 public newRewardRatio;

    ISystemRegistry internal immutable systemRegistry;

    address public immutable rewardToken;
    address public immutable operator;
    IStakeTracking public immutable stakeTracker;

    uint256 public periodInBlockFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateBlock;
    uint256 public rewardPerTokenStored;
    uint256 public queuedRewards;
    uint256 public currentRewards;
    uint256 public historicalRewards;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 public tokeLockDuration = 90 days;

    constructor(
        ISystemRegistry _systemRegistry,
        address _stakeTracker,
        address _operator,
        address _rewardToken,
        uint256 _newRewardRate,
        uint256 _durationInBlock
    ) SecurityBase(address(_systemRegistry.accessController())) {
        Errors.verifyNotZero(_stakeTracker, "_stakeTracker");
        Errors.verifyNotZero(_operator, "_operator");
        Errors.verifyNotZero(_rewardToken, "_rewardToken");

        systemRegistry = _systemRegistry;
        operator = _operator;
        rewardToken = _rewardToken;
        stakeTracker = IStakeTracking(_stakeTracker);
        newRewardRatio = _newRewardRate;
        durationInBlock = _durationInBlock;
    }

    modifier stakeTrackerOnly() {
        if (msg.sender != address(stakeTracker)) {
            revert Errors.AccessDenied();
        }
        _;
    }

    // modifier operatorOnly() {
    //     if (msg.sender != operator) {
    //         revert OperatorOnly();
    //     }
    //     _;
    // }

    function _updateReward(address account) internal {
        uint256 earnedRewards = 0;
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = lastBlockRewardApplicable();

        if (account != address(0)) {
            earnedRewards = earned(account);
            rewards[account] = earnedRewards;
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }

        emit UserRewardUpdated(account, earnedRewards, rewardPerTokenStored);
    }

    function totalSupply() public view returns (uint256) {
        return stakeTracker.totalSupply();
    }

    function balanceOf(address account) public view returns (uint256) {
        return stakeTracker.balanceOf(account);
    }

    function lastBlockRewardApplicable() public view returns (uint256) {
        return block.number < periodInBlockFinish ? block.number : periodInBlockFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        uint256 total = totalSupply();
        if (total == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + ((lastBlockRewardApplicable() - lastUpdateBlock) * rewardRate * 1e18 / total);
    }

    function earned(address account) public view returns (uint256) {
        return (balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
    }

    function setDurationInBlock(uint256 _durationInBlock) external hasRole(Roles.DV_REWARD_MANAGER_ROLE) {
        durationInBlock = _durationInBlock;
        emit RewardDurationUpdated(_durationInBlock);
    }

    function setNewRewardRate(uint256 _newRewardRate) external hasRole(Roles.DV_REWARD_MANAGER_ROLE) {
        newRewardRatio = _newRewardRate;
        emit NewRewardRateUpdated(_newRewardRate);
    }

    function queueNewRewards(uint256 newRewards) external hasRole(Roles.LIQUIDATOR_ROLE) {
        newRewards += queuedRewards;

        if (block.number >= periodInBlockFinish) {
            notifyRewardAmount(newRewards);
            queuedRewards = 0;
        } else {
            uint256 elapsedBlock = block.number - periodInBlockFinish - durationInBlock;
            uint256 currentAtNow = rewardRate * elapsedBlock;
            uint256 queuedRatio = currentAtNow * 1000 / newRewards;

            if (queuedRatio < newRewardRatio) {
                notifyRewardAmount(newRewards);
                queuedRewards = 0;
            } else {
                queuedRewards = newRewards;
            }
        }

        emit QueuedRewardsUpdated(queuedRewards);
    }

    function notifyRewardAmount(uint256 reward) internal {
        _updateReward(address(0));
        historicalRewards += reward;

        if (block.number < periodInBlockFinish) {
            uint256 remaining = periodInBlockFinish - block.number;
            // slither-disable-next-line divide-before-multiply
            uint256 leftover = remaining * rewardRate;
            reward += leftover;
        }

        rewardRate = reward / durationInBlock;
        currentRewards = reward;
        lastUpdateBlock = block.number;
        periodInBlockFinish = block.number + durationInBlock;
        emit RewardAdded(reward, rewardRate, lastUpdateBlock, periodInBlockFinish, historicalRewards);
    }

    function setTokeLockDuration(uint256 _tokeLockDuration) external hasRole(Roles.DV_REWARD_MANAGER_ROLE) {
        Errors.verifyNotZero(_tokeLockDuration, "_tokeLockDuration");

        // if duration is not set to 0 (that would turn off functionality), make sure it's long enough for gpToke
        if (_tokeLockDuration > 0 && _tokeLockDuration < systemRegistry.gpToke().minStakeDuration()) {
            revert IGPToke.StakingDurationTooShort();
        }

        tokeLockDuration = _tokeLockDuration;
        emit TokeLockDurationUpdated(_tokeLockDuration);
    }

    function _getReward(address account) internal {
        Errors.verifyNotZero(account, "account");

        uint256 reward = earned(account);
        (IGPToke gpToke, address tokeAddress) = (systemRegistry.gpToke(), address(systemRegistry.toke()));

        // slither-disable-next-line incorrect-equality
        if (reward == 0) return;

        rewards[account] = 0;
        emit RewardPaid(account, reward);

        // if NOT toke, or staking is turned off (by duration = 0), just send reward back
        if (rewardToken != tokeAddress || tokeLockDuration == 0) {
            IERC20(rewardToken).safeTransfer(account, reward);
        } else {
            // authorize gpToke to get our reward Toke
            // slither-disable-next-line unused-return
            IERC20(address(tokeAddress)).approve(address(gpToke), reward);
            // stake Toke
            gpToke.stake(reward, tokeLockDuration, account);
        }
    }

    function _withdraw(address account, uint256 amount) internal {
        Errors.verifyNotZero(account, "account");
        Errors.verifyNotZero(amount, "amount");

        emit Withdrawn(account, amount);
    }

    function _stake(address account, uint256 amount) internal {
        Errors.verifyNotZero(account, "account");
        Errors.verifyNotZero(amount, "amount");

        emit Staked(account, amount);
    }
}
