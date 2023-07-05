// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";

import { IStakeTracking } from "src/interfaces/rewarders/IStakeTracking.sol";
import { IMainRewarder } from "src/interfaces/rewarders/IMainRewarder.sol";
import { IExtraRewarder } from "src/interfaces/rewarders/IExtraRewarder.sol";
import { AbstractRewarder } from "src/rewarders/AbstractRewarder.sol";

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";

/**
 * @title MainRewarder
 * @notice The MainRewarder contract extends the AbstractRewarder and
 * manages the distribution of main rewards along with additional rewards
 * from ExtraRewarder contracts.
 */
contract MainRewarder is AbstractRewarder, IMainRewarder, ReentrancyGuard {
    address[] public extraRewards;

    constructor(
        ISystemRegistry _systemRegistry,
        address _stakeTracker,
        address _rewardToken,
        uint256 _newRewardRatio,
        uint256 _durationInBlock
    ) AbstractRewarder(_systemRegistry, _stakeTracker, _rewardToken, _newRewardRatio, _durationInBlock) { }

    function extraRewardsLength() external view returns (uint256) {
        return extraRewards.length;
    }

    function addExtraReward(address reward) external hasRole(Roles.DV_REWARD_MANAGER_ROLE) {
        Errors.verifyNotZero(reward, "reward");

        extraRewards.push(reward);
    }

    function clearExtraRewards() external onlyStakeTracker {
        delete extraRewards;
    }

    function withdraw(address account, uint256 amount, bool claim) public onlyStakeTracker {
        _updateReward(account);
        _withdraw(account, amount);

        // slither-disable-start calls-loop
        for (uint256 i = 0; i < extraRewards.length; ++i) {
            IExtraRewarder(extraRewards[i]).withdraw(account, amount);
        }
        // slither-disable-end calls-loop

        if (claim) {
            getReward(account, true);
        }
    }

    function stake(address account, uint256 amount) public onlyStakeTracker {
        _updateReward(account);
        _stake(account, amount);

        // slither-disable-start calls-loop
        for (uint256 i = 0; i < extraRewards.length; ++i) {
            IExtraRewarder(extraRewards[i]).stake(account, amount);
        }
        // slither-disable-end calls-loop
    }

    function getReward(address account, bool claimExtras) public nonReentrant {
        _updateReward(account);
        _getReward(account);

        //also get rewards from linked rewards
        if (claimExtras) {
            for (uint256 i = 0; i < extraRewards.length; ++i) {
                // slither-disable-start calls-loop
                IExtraRewarder(extraRewards[i]).getReward(account);
                // slither-disable-end calls-loop
            }
        }
    }

    function getReward() external {
        getReward(msg.sender, true);
    }
}
