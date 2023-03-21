//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AccessControl } from "openzeppelin-contracts/access/AccessControl.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { IPlasmaVaultRegistry } from "src/interfaces/vault/IPlasmaVaultRegistry.sol";
import { IPlasmaVault } from "src/interfaces/vault/IPlasmaVault.sol";

import { Errors } from "src/utils/errors.sol";

contract PlasmaVaultRegistry is IPlasmaVaultRegistry, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _vaults;
    EnumerableSet.AddressSet private _assets;
    mapping(address => EnumerableSet.AddressSet) private _vaultsByAsset;

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

        address asset = IPlasmaVault(poolAddress).asset();

        if (!_vaults.add(poolAddress)) revert PoolAlreadyExists(poolAddress);
        //slither-disable-next-line unused-return
        if (!_assets.contains(asset)) _assets.add(asset);
        if (!_vaultsByAsset[asset].add(poolAddress)) revert PoolAlreadyExists(poolAddress);

        emit PoolAdded(asset, poolAddress);
    }

    function removePool(address poolAddress) external onlyUpdater {
        if (poolAddress == address(0)) revert ZeroAddress();

        // remove from pools list
        if (!_vaults.remove(poolAddress)) revert PoolNotFound(poolAddress);

        address asset = IPlasmaVault(poolAddress).asset();

        // remove from assets list if this was the last vault for that asset
        if (_vaultsByAsset[asset].length() == 1) {
            //slither-disable-next-line unused-return
            _assets.remove(asset);
        }

        // remove from poolsByAsset mapping
        if (!_vaultsByAsset[asset].remove(poolAddress)) revert PoolNotFound(poolAddress);

        emit PoolRemoved(asset, poolAddress);
    }

    ///////////////////////////////////////////////////////////////////
    //
    //                        Enumeration Methods
    //
    ///////////////////////////////////////////////////////////////////

    function isPool(address poolAddress) external view override returns (bool) {
        return _vaults.contains(poolAddress);
    }

    function listPools() external view returns (address[] memory) {
        return _vaults.values();
    }

    function listPoolsForAsset(address asset) external view returns (address[] memory) {
        return _vaultsByAsset[asset].values();
    }
}
