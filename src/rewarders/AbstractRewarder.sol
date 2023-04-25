// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IStakeTracking } from "../interfaces/rewarders/IStakeTracking.sol";
import { IBaseRewarder } from "../interfaces/rewarders/IBaseRewarder.sol";

abstract contract AbstractRewarder is IBaseRewarder, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @dev The duration of the reward period in blocks.
     */
    uint256 public durationInBlock = 100;

    /**
     * @dev The constant ratio for queuing new rewards.
     *  It is used to determine if the new rewards should be distributed immediately or queued for later.
     *  If the ratio of current rewards to the sum of new and queued rewards is less than NEW_REWARD_RATIO,
     *  the new rewards are distributed immediately; otherwise, they are added to the queue.
     */
    uint256 public constant NEW_REWARD_RATIO = 830;

    address public immutable rewardToken;
    address public immutable operator;
    IStakeTracking public immutable stakeTracker;

    uint256 public periodInBlockFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateBlock;
    uint256 public rewardPerTokenStored;
    uint256 public queuedRewards = 0;
    uint256 public currentRewards = 0;
    uint256 public historicalRewards = 0;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    constructor(address _stakeTracker, address _operator, address _rewardToken) {
        if (_stakeTracker == address(0) || _operator == address(0) || _rewardToken == address(0)) {
            revert ZeroAddress();
        }
        operator = _operator;
        rewardToken = _rewardToken;
        stakeTracker = IStakeTracking(_stakeTracker);
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

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = lastBlockRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
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
    }

    function queueNewRewards(uint256 newRewards) external operatorOnly {
        newRewards += queuedRewards;

        if (block.number >= periodInBlockFinish) {
            notifyRewardAmount(newRewards);
            queuedRewards = 0;
            return;
        }

        uint256 elapsedBlock = block.number - periodInBlockFinish - durationInBlock;
        uint256 currentAtNow = rewardRate * elapsedBlock;
        uint256 queuedRatio = currentAtNow * 1000 / newRewards;

        if (queuedRatio < NEW_REWARD_RATIO) {
            notifyRewardAmount(newRewards);
            queuedRewards = 0;
        } else {
            queuedRewards = newRewards;
        }
    }

    function notifyRewardAmount(uint256 reward) internal updateReward(address(0)) {
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
        emit RewardAdded(reward);
    }

    function _getReward(address account) internal nonReentrant {
        uint256 reward = earned(account);
        if (reward > 0) {
            rewards[account] = 0;
            IERC20(rewardToken).safeTransfer(account, reward);
            emit RewardPaid(account, reward);
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
