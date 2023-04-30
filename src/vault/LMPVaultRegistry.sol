//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AccessControl } from "openzeppelin-contracts/access/AccessControl.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { SecurityBase } from "src/security/SecurityBase.sol";
import { Roles } from "src/libs/Roles.sol";

import { ILMPVaultRegistry } from "src/interfaces/vault/ILMPVaultRegistry.sol";
import { ILMPVault } from "src/interfaces/vault/ILMPVault.sol";

import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";

import { Errors } from "src/utils/Errors.sol";

contract LMPVaultRegistry is ILMPVaultRegistry, SecurityBase {
    using EnumerableSet for EnumerableSet.AddressSet;

    ISystemRegistry public immutable systemRegistry;

    EnumerableSet.AddressSet private _vaults;
    EnumerableSet.AddressSet private _assets;
    mapping(address => EnumerableSet.AddressSet) private _vaultsByAsset;

    constructor(ISystemRegistry _systemRegistry) SecurityBase(address(_systemRegistry.accessController())) {
        systemRegistry = _systemRegistry;
    }

    modifier onlyUpdater() {
        if (!_hasRole(Roles.REGISTRY_UPDATER, msg.sender)) revert PermissionDenied();
        _;
    }

    ///////////////////////////////////////////////////////////////////
    //
    //                        Update Methods
    //
    ///////////////////////////////////////////////////////////////////

    function addVault(address vaultAddress) external onlyUpdater {
        if (vaultAddress == address(0)) revert ZeroAddress();

        address asset = ILMPVault(vaultAddress).asset();

        if (!_vaults.add(vaultAddress)) revert VaultAlreadyExists(vaultAddress);
        //slither-disable-next-line unused-return
        if (!_assets.contains(asset)) _assets.add(asset);
        if (!_vaultsByAsset[asset].add(vaultAddress)) revert VaultAlreadyExists(vaultAddress);

        emit VaultAdded(asset, vaultAddress);
    }

    function removeVault(address vaultAddress) external onlyUpdater {
        if (vaultAddress == address(0)) revert ZeroAddress();

        // remove from vaults list
        if (!_vaults.remove(vaultAddress)) revert VaultNotFound(vaultAddress);

        address asset = ILMPVault(vaultAddress).asset();

        // remove from assets list if this was the last vault for that asset
        if (_vaultsByAsset[asset].length() == 1) {
            //slither-disable-next-line unused-return
            _assets.remove(asset);
        }

        // remove from vaultsByAsset mapping
        if (!_vaultsByAsset[asset].remove(vaultAddress)) revert VaultNotFound(vaultAddress);

        emit VaultRemoved(asset, vaultAddress);
    }

    ///////////////////////////////////////////////////////////////////
    //
    //                        Enumeration Methods
    //
    ///////////////////////////////////////////////////////////////////

    function isVault(address vaultAddress) external view override returns (bool) {
        return _vaults.contains(vaultAddress);
    }

    function listVaults() external view returns (address[] memory) {
        return _vaults.values();
    }

    function listVaultsForAsset(address asset) external view returns (address[] memory) {
        return _vaultsByAsset[asset].values();
    }
}
