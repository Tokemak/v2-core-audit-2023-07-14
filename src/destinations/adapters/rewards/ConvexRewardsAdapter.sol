// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IBaseRewardPool } from "../../../interfaces/external/convex/IBaseRewardPool.sol";
import { IClaimableRewardsAdapter } from "../../../interfaces/destinations/IClaimableRewardsAdapter.sol";

contract ConvexRewardsAdapter is IClaimableRewardsAdapter, ReentrancyGuard {
    // slither-disable-start calls-loop
    /**
     * @param gauge The gauge to claim rewards from
     */
    function claimRewards(address gauge) public nonReentrant returns (uint256[] memory, IERC20[] memory) {
        if (gauge == address(0)) revert TokenAddressZero();

        address account = address(this);

        IBaseRewardPool rewardPool = IBaseRewardPool(gauge);
        uint256 extraRewardsLength = rewardPool.extraRewardsLength();

        uint256[] memory balancesBefore = new uint256[](extraRewardsLength + 1);
        uint256[] memory amountsClaimed = new uint256[](extraRewardsLength + 1);
        IERC20[] memory rewardTokens = new IERC20[](extraRewardsLength + 1);

        // add pool rewards tokens and extra rewards tokens to rewardTokens array
        IERC20 rewardToken = rewardPool.rewardToken();
        rewardTokens[extraRewardsLength] = rewardToken;
        if (extraRewardsLength > 0) {
            for (uint256 i = 0; i < extraRewardsLength; ++i) {
                address extraReward = rewardPool.extraRewards(i);
                rewardTokens[i] = IBaseRewardPool(extraReward).rewardToken();
            }
        }

        // get balances before
        uint256 tokensLength = rewardTokens.length;
        for (uint256 i = 0; i < tokensLength; ++i) {
            balancesBefore[i] = rewardTokens[i].balanceOf(account);
        }

        // claim rewards
        bool result = rewardPool.getReward(account, true);
        if (!result) {
            revert ClaimRewardsFailed();
        }

        // get balances after and calculate amounts claimed
        for (uint256 i = 0; i < tokensLength; ++i) {
            uint256 balance = rewardTokens[i].balanceOf(account);

            amountsClaimed[i] = balance - balancesBefore[i];
        }

        emit RewardsClaimed(rewardTokens, amountsClaimed);

        return (amountsClaimed, rewardTokens);
    }
    // slither-disable-end calls-loop
}
