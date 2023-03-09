//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title Keep track of Pools created through the Pool Factory
interface IPlasmaPoolRegistry {
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
    event PoolAdded(address indexed asset, address indexed pool);
    event PoolRemoved(address indexed asset, address indexed pool);

    ///////////////////////////////////////////////////////////////////
    //                        Functions
    ///////////////////////////////////////////////////////////////////

    /// @notice Checks if an address is a valid pool
    /// @param poolAddress Pool address to be added
    function isPool(address poolAddress) external view returns (bool);

    /// @notice Registers a pool
    /// @param poolAddress Pool address to be added
    function addPool(address poolAddress) external;

    /// @notice Removes pool registration
    /// @param poolAddress Pool address to be removed
    function removePool(address poolAddress) external;

    /// @notice Returns a list of all registered pools
    function listPools() external view returns (address[] memory);

    /// @notice Returns a list of all registered pools for a given asset
    /// @param asset Asset address
    function listPoolsForAsset(address asset) external view returns (address[] memory);
}
