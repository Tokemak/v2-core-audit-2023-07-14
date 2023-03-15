// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { ILiquidityGaugeV2 } from "../interfaces/external/curve/ILiquidityGaugeV2.sol";
import { IClaimableRewards } from "./IClaimableRewards.sol";

contract CurveAdapter is IClaimableRewards, ReentrancyGuard {
    // solhint-disable-next-line var-name-mixedcase
    uint256 private constant MAX_REWARDS = 8;

    // slither-disable-start calls-loop
    /**
     * @param gauge The gauge to claim rewards from
     */
    function claimRewards(address gauge) public nonReentrant returns (uint256[] memory, IERC20[] memory) {
        if (gauge == address(0)) revert TokenAddressZero();

        address account = address(this);

        ILiquidityGaugeV2 rewardPool = ILiquidityGaugeV2(gauge);

        IERC20[] memory tempRewardTokens = new IERC20[](MAX_REWARDS);
        uint256 rewardsLength = 0;

        // Curve Pool don't have a method to get the reward tokens length
        // so we need to iterate until we get a zero address.
        // All Curve pools have MAX_REWARDS set to 8
        // https://etherscan.deth.net/address/0x182b723a58739a9c974cfdb385ceadb237453c28
        for (uint256 i = 0; i < MAX_REWARDS; ++i) {
            address rewardToken = rewardPool.reward_tokens(i);
            if (rewardToken == address(0)) {
                break;
            }
            tempRewardTokens[i] = IERC20(rewardToken);
            ++rewardsLength;
        }

        // resize the tokens array to the correct size
        IERC20[] memory rewardTokens = new IERC20[](rewardsLength);
        for (uint256 i = 0; i < rewardsLength;) {
            rewardTokens[i] = tempRewardTokens[i];
            unchecked {
                ++i;
            }
        }

        uint256[] memory balancesBefore = new uint256[](rewardsLength);
        uint256[] memory amountsClaimed = new uint256[](rewardsLength);

        // get balances before
        for (uint256 i = 0; i < rewardsLength; ++i) {
            balancesBefore[i] = rewardTokens[i].balanceOf(account);
        }

        // claim rewards
        rewardPool.claim_rewards(account);

        // get balances after and calculate amounts claimed
        for (uint256 i = 0; i < rewardsLength; ++i) {
            uint256 balance = rewardTokens[i].balanceOf(account);

            amountsClaimed[i] = balance - balancesBefore[i];
        }

        emit RewardsClaimed(rewardTokens, amountsClaimed);

        return (amountsClaimed, rewardTokens);
    }
    // slither-disable-end calls-loop
}
