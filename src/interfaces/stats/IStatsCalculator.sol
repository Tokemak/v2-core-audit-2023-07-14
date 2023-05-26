// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Stats } from "src/libs/Stats.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";

/// @title Capture information about a pool or destination
interface IStatsCalculator {
    /// @notice The id for this instance of a calculator
    function getAprId() external view returns (bytes32);

    /// @notice The id of the underlying asset/pool/destination this calculator represents
    /// @dev This may be a generated address
    function getAddressId() external view returns (address);

    /// @notice Setup the calculator after it has been copied
    /// @dev Should only be executed one time
    /// @param _systemRegistry instance of the system this calculator applies to
    /// @param dependentAprIds apr ids that cover the dependencies of this calculator
    /// @param initData setup data specific to this type of calculator
    function initialize(
        ISystemRegistry _systemRegistry,
        bytes32[] calldata dependentAprIds,
        bytes calldata initData
    ) external;

    /// @notice Current stats data including dependencies
    /// @dev Some stat values may be empty depending on the hierarchy of the calculator
    /// @return stats information about this pool or destination combination
    function current() external view returns (Stats.CalculatedStats memory stats);

    /// @notice Capture stat data about this setup
    function snapshot() external;
}
