// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Stats } from "src/libs/Stats.sol";
import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IStatsCalculator } from "src/interfaces/stats/IStatsCalculator.sol";
import { ICurveRegistry } from "src/interfaces/external/curve/ICurveRegistry.sol";
import { IStatsCalculatorRegistry } from "src/interfaces/stats/IStatsCalculatorRegistry.sol";

/// @title Base Stats Calculator
/// @notice Captures common behavior across all calculators
/// @dev Performs security checks and general roll-up behavior
abstract contract BaseStatsCalculator is IStatsCalculator, SecurityBase {
    /// @notice Dependent calculators that should be rolled into this one
    IStatsCalculator[] public calculators;

    modifier onlyStatsSnapshot() {
        if (!_hasRole(Roles.STATS_SNAPSHOT_ROLE, msg.sender)) {
            revert Errors.MissingRole(Roles.STATS_SNAPSHOT_ROLE, msg.sender);
        }
        _;
    }

    constructor(ISystemRegistry _systemRegistry) SecurityBase(address(_systemRegistry.accessController())) { }

    /// @inheritdoc IStatsCalculator
    function current() external view override returns (Stats.CalculatedStats memory stats) {
        // Loop over the tokens to get their data base apr or other data
        uint256 nCalcs = calculators.length;
        for (uint256 i = 0; i < nCalcs;) {
            //slither-disable-next-line calls-loop
            stats = Stats.combineStats(stats, calculators[i].current());

            unchecked {
                ++i;
            }
        }

        stats = _current(stats);
    }

    /// @inheritdoc IStatsCalculator
    function snapshot() external override onlyStatsSnapshot {
        _snapshot();
    }

    /// @notice Capture stat data about this setup
    /// @dev This is protected by the STATS_SNAPSHOT_ROLE
    function _snapshot() internal virtual;

    /// @notice Augment the dependent stats data with information specific to this setup
    /// @dev Roll-up of dependent calculators is already done and will be passed to you
    /// @return stats information about this, and dependent, pool or destination combination
    function _current(Stats.CalculatedStats memory stats)
        internal
        view
        virtual
        returns (Stats.CalculatedStats memory);
}
