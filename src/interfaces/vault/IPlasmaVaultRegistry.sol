//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISystemBound } from "src/interfaces/ISystemBound.sol";

/// @title Keep track of Pools created through the Pool Factory
interface IPlasmaVaultRegistry is ISystemBound {
    ///////////////////////////////////////////////////////////////////
    //                        Errors
    ///////////////////////////////////////////////////////////////////

    error ZeroAddress();
    error PoolNotFound(address poolAddress);
    error PoolAlreadyExists(address poolAddress);
    error PermissionDenied();

    ///////////////////////////////////////////////////////////////////
    //                        Events
    ///////////////////////////////////////////////////////////////////
    event PoolAdded(address indexed asset, address indexed vault);
    event PoolRemoved(address indexed asset, address indexed vault);

    ///////////////////////////////////////////////////////////////////
    //                        Functions
    ///////////////////////////////////////////////////////////////////

    /// @notice Checks if an address is a valid vault
    /// @param poolAddress Pool address to be added
    function isPool(address poolAddress) external view returns (bool);

    /// @notice Registers a vault
    /// @param poolAddress Pool address to be added
    function addPool(address poolAddress) external;

    /// @notice Removes vault registration
    /// @param poolAddress Pool address to be removed
    function removePool(address poolAddress) external;

    /// @notice Returns a list of all registered pools
    function listPools() external view returns (address[] memory);

    /// @notice Returns a list of all registered pools for a given asset
    /// @param asset Asset address
    function listPoolsForAsset(address asset) external view returns (address[] memory);
}
