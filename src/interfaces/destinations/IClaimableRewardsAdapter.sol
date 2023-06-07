// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IDestinationAdapter } from "./IDestinationAdapter.sol";

/**
 * @dev This interface is intended to be used with contracts that are meant to be delegate called.
 * Contracts that inherit from this interface should not have any state variables.
 */
interface IClaimableRewardsAdapter is IDestinationAdapter {
    error ClaimRewardsFailed();
    error TokenAddressZero();

    /**
     * @dev Emitted when rewards are claimed.
     * @param rewardTokens The tokens received as rewards.
     * @param amountsClaimed The amounts of each token claimed.
     */
    event RewardsClaimed(IERC20[] rewardTokens, uint256[] amountsClaimed);

    /**
     * @notice Claim rewards for a given token and account
     * @param gauge The address of the token to claim rewards for
     * @return amountsClaimed The amounts of rewards claimed
     * @return tokens The tokens that rewards were claimed for
     */
    function claimRewards(address gauge) external returns (uint256[] memory, IERC20[] memory);
}
