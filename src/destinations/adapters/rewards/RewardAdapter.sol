// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

/// @title Common functionality for reward adapter libraries
library RewardAdapter {
    error ClaimRewardsFailed();

    event RewardsClaimed(address[], uint256[]);

    /// @notice Emit RewardsClaimed(address[],uint256[]) event common to all reward claim libraries
    /// @param tokens reward token addresses claimed
    /// @param amounts amounts of each token claimed
    function emitRewardsClaimed(address[] memory tokens, uint256[] memory amounts) internal {
        emit RewardsClaimed(tokens, amounts);
    }
}
