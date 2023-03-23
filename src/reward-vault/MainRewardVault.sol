// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { IStakeTracking } from "../interfaces/reward-vault/IStakeTracking.sol";
import { IMainReward } from "../interfaces/reward-vault/IMainReward.sol";
import { IExtraReward } from "../interfaces/reward-vault/IExtraReward.sol";
import { AbstractRewardVault } from "./AbstractRewardVault.sol";

/**
 * @title MainRewardVault
 * @notice The MainRewardVault contract extends the AbstractRewardVault and
 * manages the distribution of main rewards along with additional rewards
 * from ExtraRewardVault contracts.
 */
contract MainRewardVault is AbstractRewardVault, IMainReward {
    address public immutable rewardManager;
    address[] public extraRewards;

    constructor(
        address _stakeTracker,
        address _operator,
        address _rewardToken,
        address _rewardManager
    ) AbstractRewardVault(_stakeTracker, _operator, _rewardToken) {
        if (_rewardManager == address(0)) {
            revert ZeroAddress();
        }
        rewardManager = _rewardManager;
    }

    modifier rewardManagerOnly() {
        if (msg.sender != rewardManager) {
            revert RewardManagerOnly();
        }
        _;
    }

    function extraRewardsLength() external view returns (uint256) {
        return extraRewards.length;
    }

    function addExtraReward(address reward) external rewardManagerOnly {
        if (reward == address(0)) {
            revert ZeroAddress();
        }

        extraRewards.push(reward);
    }

    function clearExtraRewards() external stakeTrackerOnly {
        delete extraRewards;
    }

    function withdraw(address account, uint256 amount, bool claim) public stakeTrackerOnly updateReward(account) {
        _withdraw(account, amount);

        // slither-disable-start calls-loop
        for (uint256 i = 0; i < extraRewards.length; i++) {
            IExtraReward(extraRewards[i]).withdraw(account, amount);
        }
        // slither-disable-end calls-loop

        if (claim) {
            getReward(account, true);
        }
    }

    function stake(address account, uint256 amount) public stakeTrackerOnly updateReward(account) {
        _stake(account, amount);

        // slither-disable-start calls-loop
        for (uint256 i = 0; i < extraRewards.length; i++) {
            IExtraReward(extraRewards[i]).stake(account, amount);
        }
        // slither-disable-end calls-loop
    }

    function getReward(address account, bool claimExtras) public updateReward(account) {
        _getReward(account);

        //also get rewards from linked rewards
        if (claimExtras) {
            for (uint256 i = 0; i < extraRewards.length; i++) {
                // slither-disable-start calls-loop
                IExtraReward(extraRewards[i]).getReward(account);
                // slither-disable-end calls-loop
            }
        }
    }

    function getReward() external {
        getReward(msg.sender, true);
    }
}
