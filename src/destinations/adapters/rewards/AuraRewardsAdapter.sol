// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { ConvexRewards } from "src/destinations/adapters/rewards/ConvexRewardsAdapter.sol";

/**
 * @title AuraAdapter
 * @dev This contract implements an adapter for interacting with Aura's reward system.
 * We're using a Convex Adapter as Aura uses the Convex interfaces for LPs staking.
 */
//slither-disable-next-line missing-inheritance
library AuraRewards {
    /// @notice Claim rewards for Aura staked LP tokens
    /// @param gauge the reward contract in Aura
    /// @param defaultToken the reward token always provided. AURA for Aura
    /// @param sendTo the destination of the rewarded tokens
    /// @return amounts the amount of each token that was claimed
    /// @return tokens the tokens that were claimed
    function claimRewards(
        address gauge,
        address defaultToken,
        address sendTo
    ) public returns (uint256[] memory amounts, address[] memory tokens) {
        (amounts, tokens) = ConvexRewards.claimRewards(gauge, defaultToken, sendTo);
    }

    /// @notice Claim rewards for Aura staked LP tokens
    /// @param gauge the reward contract in Aura
    /// @param defaultToken the reward token always provided. AURA for Aura
    /// @return amounts the amount of each token that was claimed
    /// @return tokens the tokens that were claimed
    function claimRewards(
        address gauge,
        address defaultToken
    ) public returns (uint256[] memory amounts, address[] memory tokens) {
        (amounts, tokens) = ConvexRewards.claimRewards(gauge, defaultToken, address(this));
    }
}
