// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Stats } from "src/stats/Stats.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ILSTStats } from "src/interfaces/stats/ILSTStats.sol";

/// @title Return stats DEXs with LSTs
interface IDexLSTStats {
    struct DexLSTStatsData {
        uint256 feeApr;
        uint256[] reservesInEth;
        ILSTStats.LSTStatsData[] lstStatsData;
    }

    /// @notice Get the current stats for the DEX with underlying LST tokens
    /// @dev Returned data is a combination of current data and filtered snapshots
    /// @return dexLSTStatsData current data on the DEX
    function current() external returns (DexLSTStatsData memory dexLSTStatsData);
}
