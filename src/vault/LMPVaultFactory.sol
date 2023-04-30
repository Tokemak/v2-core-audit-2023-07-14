// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { ILMPVaultFactory } from "src/interfaces/vault/ILMPVaultFactory.sol";
import { ILMPVaultRegistry } from "src/interfaces/vault/ILMPVaultRegistry.sol";
import { ILMPVault, LMPVault } from "src/vault/LMPVault.sol";
import { StrategyFactory } from "src/strategy/StrategyFactory.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";

contract LMPVaultFactory is ILMPVaultFactory, SecurityBase {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    mapping(bytes32 => address) public vaultTypeToPrototype;
    ILMPVaultRegistry public immutable vaultRegistry;

    constructor(address _vaultRegistry, address _accessController) SecurityBase(_accessController) {
        vaultRegistry = ILMPVaultRegistry(_vaultRegistry);
    }

    function createVault(
        address _vaultAsset,
        address _strategy,
        address _rewarder,
        bytes calldata /*extraParams*/
    ) external returns (address newVaultAddress) {
        if (!_hasRole(Roles.CREATE_POOL_ROLE, msg.sender)) {
            revert Errors.AccessDenied();
        }

        // verify params
        if (_vaultAsset == address(0)) revert Errors.ZeroAddress("vaultAsset");

        // create new and initialize
        newVaultAddress = address(
            new LMPVault(
            _vaultAsset,
            address(accessController),
            _strategy,
            _rewarder
            )
        );

        // add to VaultRegistry
        vaultRegistry.addVault(newVaultAddress);
    }
}
