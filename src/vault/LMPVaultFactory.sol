// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ILMPVaultFactory } from "src/interfaces/vault/ILMPVaultFactory.sol";
import { ILMPVaultRegistry } from "src/interfaces/vault/ILMPVaultRegistry.sol";
import { ILMPVault, LMPVault } from "src/vault/LMPVault.sol";
import { StrategyFactory } from "src/strategy/StrategyFactory.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";

contract LMPVaultFactory is ILMPVaultFactory, SecurityBase {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    ISystemRegistry public immutable systemRegistry;
    ILMPVaultRegistry public immutable vaultRegistry;
    mapping(bytes32 => address) public vaultTypeToPrototype;

    constructor(ISystemRegistry _systemRegistry) SecurityBase(address(_systemRegistry.accessController())) {
        Errors.verifyNotZero(address(_systemRegistry), "systemRegistry");

        systemRegistry = _systemRegistry;
        vaultRegistry = systemRegistry.lmpVaultRegistry();
    }

    function createVault(
        address _vaultAsset,
        address _rewarder,
        bytes calldata /*extraParams*/
    ) external returns (address newVaultAddress) {
        if (!_hasRole(Roles.CREATE_POOL_ROLE, msg.sender)) {
            revert Errors.AccessDenied();
        }

        // verify params
        Errors.verifyNotZero(_vaultAsset, "vaultAsset");

        // create new and initialize
        newVaultAddress = address(
            new LMPVault(
                systemRegistry,
                _vaultAsset,
                _rewarder
            )
        );

        // add to VaultRegistry
        vaultRegistry.addVault(newVaultAddress);
    }
}
