// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { Errors } from "src/utils/Errors.sol";
import { IReward } from "src/interfaces/external/maverick/IReward.sol";
import { IClaimableRewardsAdapter } from "src/interfaces/destinations/IClaimableRewardsAdapter.sol";

contract MaverickRewardsAdapter is IClaimableRewardsAdapter, ReentrancyGuard {
    /// @inheritdoc IClaimableRewardsAdapter
    function claimRewards(address _rewarder) public nonReentrant returns (uint256[] memory, IERC20[] memory) {
        Errors.verifyNotZero(_rewarder, "rewarder");
        address account = address(this);

        IReward rewarder = IReward(_rewarder);

        // Fetching the earned rewards information
        IReward.EarnedInfo[] memory earnedInfos = rewarder.earned(account);
        uint256 length = earnedInfos.length;

        IERC20[] memory rewardTokens = new IERC20[](length);
        uint256[] memory amountsClaimed = new uint256[](length);

        // Iterating over each reward info, if earned is not zero, reward is claimed
        for (uint256 i = 0; i < length; ++i) {
            IReward.EarnedInfo memory earnedInfo = earnedInfos[i];
            IERC20 rewardToken = earnedInfo.rewardToken;
            rewardTokens[i] = rewardToken;

            if (earnedInfo.earned == 0) {
                amountsClaimed[i] = 0;
                continue;
            }

            // Fetching the current balance before claiming the reward
            uint256 balanceBefore = rewardToken.balanceOf(account);

            // Claiming the reward
            // slither-disable-next-line unused-return
            rewarder.getReward(account, uint8(i));

            // Calculating the claimed amount by comparing the balance after claiming the reward
            amountsClaimed[i] = rewardToken.balanceOf(account) - balanceBefore;
        }

        emit RewardsClaimed(rewardTokens, amountsClaimed);

        return (amountsClaimed, rewardTokens);
    }
}
