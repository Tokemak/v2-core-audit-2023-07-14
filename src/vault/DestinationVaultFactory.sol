// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";
import { Clones } from "openzeppelin-contracts/proxy/Clones.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { Ownable2Step } from "openzeppelin-contracts/access/Ownable2Step.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { IDestinationVaultFactory } from "src/interfaces/vault/IDestinationVaultFactory.sol";
import { IDestinationVaultRegistry } from "src/interfaces/vault/IDestinationVaultRegistry.sol";
import { IERC20Metadata as IERC20 } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SystemComponent } from "src/SystemComponent.sol";

contract DestinationVaultFactory is SystemComponent, IDestinationVaultFactory, SecurityBase {
    using Clones for address;

    modifier onlyVaultCreator() {
        if (!_hasRole(Roles.CREATE_DESTINATION_VAULT_ROLE, msg.sender)) {
            revert Errors.MissingRole(Roles.CREATE_DESTINATION_VAULT_ROLE, msg.sender);
        }
        _;
    }

    constructor(ISystemRegistry _systemRegistry)
        SystemComponent(_systemRegistry)
        SecurityBase(address(_systemRegistry.accessController()))
    {
        // Validate the registry is in a state we can use it
        if (address(_systemRegistry.destinationTemplateRegistry()) == address(0)) {
            revert Errors.RegistryItemMissing("destinationTemplateRegistry");
        }
        if (address(_systemRegistry.destinationVaultRegistry()) == address(0)) {
            revert Errors.RegistryItemMissing("destinationVaultRegistry");
        }
    }

    /// @inheritdoc IDestinationVaultFactory
    function create(
        string memory vaultType,
        address baseAsset,
        string memory proxyName,
        bytes memory params
    ) external onlyVaultCreator {
        // Switch to the internal key from the human readable
        bytes32 key = keccak256(abi.encode(vaultType));

        // Get the template to clone
        address template = address(systemRegistry.destinationTemplateRegistry().getAdapter(key));

        Errors.verifyNotZero(template, "template");

        // Copy and set it up
        address newVault = template.clone();
        IDestinationVault(newVault).initialize(systemRegistry, IERC20(baseAsset), proxyName, params);

        // Add the vault to the registry
        systemRegistry.destinationVaultRegistry().register(newVault);
    }
}
