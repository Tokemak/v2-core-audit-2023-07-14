// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Stats } from "src/stats/Stats.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";

/// @title Return stats on base LSTs
interface ILSTStats {
    struct LSTStatsData {
        uint256 baseApr;
        uint256[] slashingCosts;
        uint256[] slashingTimestamps;
    }

    function current() external view returns (LSTStatsData memory);

    function calculateEthPerToken() external view returns (uint256);
}
