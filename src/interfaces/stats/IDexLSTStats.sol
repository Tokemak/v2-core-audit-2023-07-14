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

    function current() external returns (DexLSTStatsData memory);
}
