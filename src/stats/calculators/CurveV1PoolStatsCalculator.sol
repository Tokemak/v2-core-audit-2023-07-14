// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Stats } from "src/libs/Stats.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ICurveRegistry } from "src/interfaces/external/curve/ICurveRegistry.sol";
import { CurveV1PoolCalculatorBase } from "src/stats/calculators/base/CurveV1PoolCalculatorBase.sol";

/// @notice Calculate stats for a Curve V1 StableSwap pool
contract CurveV1PoolStatsCalculator is CurveV1PoolCalculatorBase {
    constructor(
        ISystemRegistry _systemRegistry,
        ICurveRegistry _curveRegistry
    ) CurveV1PoolCalculatorBase(_systemRegistry, _curveRegistry) { }

    /// @notice Augment the dependent stats data with information specific to this setup
    /// @dev Roll-up of dependent calculators is already done and will be passed to you
    /// @return stats information about this, and dependent, pool or destination combination
    function _current(Stats.CalculatedStats memory dependentStats)
        internal
        view
        override
        returns (Stats.CalculatedStats memory)
    {
        // Base class pulls in dependencies and adds them up

        // Add in the trading fee's we're tracking
        dependentStats.tradingFeeApr = dependentStats.tradingFeeApr + lastTradingFeeApr;

        return dependentStats;
    }

    /// @notice Capture stat data about this setup
    /// @dev This is protected by the STATS_SNAPSHOT_ROLE
    function _snapshot() internal override {
        lastTradingFeeApr = block.number / 1000;
    }
}
