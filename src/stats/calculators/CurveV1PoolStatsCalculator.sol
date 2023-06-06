// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Stats } from "src/stats/Stats.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ICurveRegistry } from "src/interfaces/external/curve/ICurveRegistry.sol";
import { CurveV1PoolCalculatorBase } from "src/stats/calculators/base/CurveV1PoolCalculatorBase.sol";
import { IStatsCalculator } from "src/interfaces/stats/IStatsCalculator.sol";

/// @notice Calculate stats for a Curve V1 StableSwap pool
contract CurveV1PoolStatsCalculator is CurveV1PoolCalculatorBase {
    constructor(
        ISystemRegistry _systemRegistry,
        ICurveRegistry _curveRegistry
    ) CurveV1PoolCalculatorBase(_systemRegistry, _curveRegistry) { }

    /// @inheritdoc IStatsCalculator
    function current() external view override returns (Stats.CalculatedStats memory) {
        return Stats.CalculatedStats({ statsType: Stats.StatsType.DEX, data: "", dependentStats: calculators });
    }

    /// @inheritdoc IStatsCalculator
    function shouldSnapshot() external view returns (bool takeSnapshot) {
        // TODO: implement real snapshot logic
        return true;
    }

    /// @notice Capture stat data about this setup
    /// @dev This is protected by the STATS_SNAPSHOT_ROLE
    function _snapshot() internal override {
        lastTradingFeeApr = block.number / 1000;
    }
}
