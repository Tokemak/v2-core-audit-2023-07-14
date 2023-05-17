// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice Stores a reference to the registry for this system
interface ISystemBound {
    /// @notice The system instance this contract is tied to
    function getSystemRegistry() external view returns (address registry);
}
