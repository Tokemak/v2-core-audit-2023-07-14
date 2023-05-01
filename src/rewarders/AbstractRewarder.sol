// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { IStakeTracking } from "../interfaces/rewarders/IStakeTracking.sol";
import { IBaseRewarder } from "../interfaces/rewarders/IBaseRewarder.sol";

/**
 * @dev An abstract contract that serves as the base for rewarder contracts.
 * It implements common functionalities for reward distribution, including calculating rewards per token,
 * tracking user rewards, and handling stake-related operations.
 * Inherited by rewarder contracts, such as MainRewarder and ExtraRewarder.
 * The contract is inspired by the Convex contract but uses block-based duration instead of timestamp-based duration.
 * Unlike Convex, it does not own the LP token but it interacts with an external LP token contract.
 */
abstract contract AbstractRewarder is IBaseRewarder {
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

    constructor(
        address _stakeTracker,
        address _operator,
        address _rewardToken,
        uint256 _newRewardRate,
        uint256 _durationInBlock
    ) {
        if (_stakeTracker == address(0) || _operator == address(0) || _rewardToken == address(0)) {
            revert ZeroAddress();
        }
        operator = _operator;
        rewardToken = _rewardToken;
        stakeTracker = IStakeTracking(_stakeTracker);
        newRewardRatio = _newRewardRate;
        durationInBlock = _durationInBlock;
    }

    modifier stakeTrackerOnly() {
        if (msg.sender != address(stakeTracker)) {
            revert StakeTrackerOnly();
        }
        _;
    }

    modifier operatorOnly() {
        if (msg.sender != operator) {
            revert OperatorOnly();
        }
        _;
    }

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

    function setDurationInBlock(uint256 _durationInBlock) external operatorOnly {
        durationInBlock = _durationInBlock;
        emit RewardDurationUpdated(_durationInBlock);
    }

    function setNewRewardRate(uint256 _newRewardRate) external operatorOnly {
        newRewardRatio = _newRewardRate;
        emit NewRewardRateUpdated(_newRewardRate);
    }

    function queueNewRewards(uint256 newRewards) external operatorOnly {
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
            uint256 leftover = remaining * rewardRate;
            reward += leftover;
        }

        rewardRate = reward / durationInBlock;
        currentRewards = reward;
        lastUpdateBlock = block.number;
        periodInBlockFinish = block.number + durationInBlock;
        emit RewardAdded(reward, rewardRate, lastUpdateBlock, periodInBlockFinish, historicalRewards);
    }

    function _getReward(address account) internal {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
            emit RewardPaid(account, reward);
            IERC20(rewardToken).safeTransfer(account, reward);
        }
    }

    function _withdraw(address account, uint256 amount) internal {
        if (amount == 0) {
            revert ZeroAmount();
        }

        emit Withdrawn(account, amount);
    }

    function _stake(address account, uint256 amount) internal {
        if (amount == 0) {
            revert ZeroAmount();
        }

        emit Staked(account, amount);
    }
}
