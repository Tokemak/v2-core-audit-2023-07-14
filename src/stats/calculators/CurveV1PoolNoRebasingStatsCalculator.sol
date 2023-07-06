// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Stats } from "src/stats/Stats.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ICurveRegistry } from "src/interfaces/external/curve/ICurveRegistry.sol";
import { CurvePoolNoRebasingCalculatorBase } from "src/stats/calculators/base/CurvePoolNoRebasingCalculatorBase.sol";
import { IStatsCalculator } from "src/interfaces/stats/IStatsCalculator.sol";
import { IDexLSTStats } from "src/interfaces/stats/IDexLSTStats.sol";
import { ICurveV1StableSwap } from "src/interfaces/external/curve/ICurveV1StableSwap.sol";
import { ICurveOwner } from "src/interfaces/external/curve/ICurveOwner.sol";

/// @notice Calculate stats for a Curve V1 StableSwap pool
contract CurveV1PoolNoRebasingStatsCalculator is CurvePoolNoRebasingCalculatorBase {
    constructor(ISystemRegistry _systemRegistry) CurvePoolNoRebasingCalculatorBase(_systemRegistry) { }

    function getVirtualPrice() internal view override returns (uint256 virtualPrice) {
        // TODO: deal with reentrancy in a different contract
        return ICurveV1StableSwap(poolAddress).get_virtual_price();
    }
}
