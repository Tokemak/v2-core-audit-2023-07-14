// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IConvexRewardPool, RewardType } from "../../../interfaces/external/convex/IConvexRewardPool.sol";
import { IClaimableRewardsAdapter } from "../../../interfaces/destinations/IClaimableRewardsAdapter.sol";

contract ConvexArbitrumRewardsAdapter is IClaimableRewardsAdapter, ReentrancyGuard {
    /**
     * @param gauge The gauge to claim rewards from
     */
    function claimRewards(address gauge) public nonReentrant returns (uint256[] memory, IERC20[] memory) {
        if (gauge == address(0)) revert TokenAddressZero();

        address account = address(this);

        IConvexRewardPool rewardPool = IConvexRewardPool(gauge);
        uint256 rewardsLength = rewardPool.rewardLength();

        uint256[] memory balancesBefore = new uint256[](rewardsLength);
        uint256[] memory amountsClaimed = new uint256[](rewardsLength);
        IERC20[] memory rewardTokens = new IERC20[](rewardsLength);

        // get balances before
        for (uint256 i = 0; i < rewardsLength; ++i) {
            RewardType memory rewardType = rewardPool.rewards(i);
            IERC20 token = IERC20(rewardType.reward_token);
            rewardTokens[i] = token;
            balancesBefore[i] = token.balanceOf(account);
        }

        // claim rewards
        rewardPool.getReward(account);

        // get balances after and calculate amounts claimed
        for (uint256 i = 0; i < rewardsLength; ++i) {
            uint256 balance = rewardTokens[i].balanceOf(account);
            amountsClaimed[i] = balance - balancesBefore[i];
        }

        emit RewardsClaimed(rewardTokens, amountsClaimed);

        return (amountsClaimed, rewardTokens);
    }
}
