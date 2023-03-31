// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { IPlasmaVaultFactory } from "src/interfaces/vault/IPlasmaVaultFactory.sol";
import { IPlasmaVaultRegistry } from "src/interfaces/vault/IPlasmaVaultRegistry.sol";
import { PlasmaVault } from "./PlasmaVault.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";
import { Roles } from "src/libs/Roles.sol";

contract PlasmaVaultFactory is IPlasmaVaultFactory, SecurityBase {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    mapping(bytes32 => address) public poolTypeToPrototype;
    EnumerableSet.Bytes32Set private _vaultTypes;

    IPlasmaVaultRegistry public immutable poolRegistry;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable POOLTYPE_PLASMAPOOL = keccak256("POOLTYPE_PLASMAPOOL");

    constructor(address _vaultRegistry, address _accessController) SecurityBase(_accessController) {
        poolRegistry = IPlasmaVaultRegistry(_vaultRegistry);
    }

    function createPool(
        bytes32 _vaultType,
        address _vaultAsset,
        bytes calldata /*extraParams*/
    ) external returns (address newPoolAddress) {
        if (!_hasRole(Roles.CREATE_POOL_ROLE, msg.sender)) {
            revert PermissionDenied();
        }

        // verify params
        if (_vaultAsset == address(0)) revert ZeroAddress();
        if (!_vaultTypes.contains(_vaultType)) revert PoolTypeNotFound();

        // create new and initialize
        newPoolAddress = address(new PlasmaVault(_vaultAsset, address(accessController)));

        // add to PoolRegistry
        poolRegistry.addPool(newPoolAddress);
    }

    ///////////////////////////////////////////////////////////////////
    //
    //                        Enumeration Methods
    //
    ///////////////////////////////////////////////////////////////////

    function listPoolTypes() external view returns (bytes32[] memory poolTypes) {
        return _vaultTypes.values();
    }

    function addPoolType(bytes32 poolType, address _plasmaPoolPrototype) public onlyOwner {
        // add prototype
        if (!_vaultTypes.add(poolType)) {
            revert PoolTypeAlreadyExists();
        }

        emit PoolTypeAdded(poolType, _plasmaPoolPrototype);
    }

    function removePoolType(bytes32 poolType) public onlyOwner {
        // remove actual prototype
        if (!_vaultTypes.remove(poolType)) {
            revert PoolTypeNotFound();
        }

        emit PoolTypeRemoved(poolType);
    }

    function replacePoolType(bytes32 poolType, address plasmaPoolPrototype) external onlyOwner {
        removePoolType(poolType);
        addPoolType(poolType, plasmaPoolPrototype);
    }
}
