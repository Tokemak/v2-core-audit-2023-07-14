//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/access/AccessControl.sol";
import "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/pool/IPlasmaPoolRegistry.sol";
import "./interfaces/pool/IPlasmaPool.sol";

contract PlasmaPoolRegistry is IPlasmaPoolRegistry, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    error ZeroAddress();
    error PoolNotFound(address poolAddress);
    error PermissionDenied();

    EnumerableSet.AddressSet private _pools;
    EnumerableSet.AddressSet private _assets;
    mapping(address => EnumerableSet.AddressSet) private _poolsByAsset;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable REGISTRY_UPDATER = keccak256("REGISTERED_ROLE");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(REGISTRY_UPDATER, msg.sender);
    }

    modifier onlyUpdater() {
        if (!hasRole(REGISTRY_UPDATER, msg.sender)) revert PermissionDenied();
        _;
    }

    ///////////////////////////////////////////////////////////////////
    //
    //                        Update Methods
    //
    ///////////////////////////////////////////////////////////////////

    function addPool(address poolAddress) external onlyUpdater {
        if (poolAddress == address(0)) revert ZeroAddress();

        address asset = IPlasmaPool(poolAddress).asset();

        _pools.add(poolAddress);
        _assets.add(asset);
        _poolsByAsset[asset].add(poolAddress);

        emit PoolAdded(asset, poolAddress);
    }

    function removePool(address poolAddress) external onlyUpdater {
        if (poolAddress == address(0)) revert ZeroAddress();
        if (!_pools.contains(poolAddress)) revert PoolNotFound(poolAddress);

        address asset = IPlasmaPool(poolAddress).asset();

        // remove from pools list
        _pools.remove(poolAddress);
        // remove from assets list if this was the last pool for that asset
        if (_poolsByAsset[asset].length() == 1) {
            _assets.remove(asset);
        }
        // remove from poolsByAsset mapping
        _poolsByAsset[asset].remove(poolAddress);

        emit PoolRemoved(asset, poolAddress);
    }

    ///////////////////////////////////////////////////////////////////
    //
    //                        Enumeration Methods
    //
    ///////////////////////////////////////////////////////////////////

    function listPools() external view returns (address[] memory) {
        return _pools.values();
    }

    function listPoolsForAsset(address asset) external view returns (address[] memory) {
        return _poolsByAsset[asset].values();
    }
}
