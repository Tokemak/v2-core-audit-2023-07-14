// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IDestinationAdapter } from "./IDestinationAdapter.sol";

interface IClaimableRewardsAdapter is IDestinationAdapter {
    error ClaimRewardsFailed();
    error TokenAddressZero();

    event RewardsClaimed(IERC20[], uint256[]);

    /**
     * @notice Claim rewards for a given token and account
     * @param gauge The address of the token to claim rewards for
     * @return amountsClaimed The amounts of rewards claimed
     * @return tokens The tokens that rewards were claimed for
     */
    function claimRewards(address gauge) external returns (uint256[] memory, IERC20[] memory);
}
