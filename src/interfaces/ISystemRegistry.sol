// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ILMPVaultRegistry } from "src/interfaces/vault/ILMPVaultRegistry.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";
import { IDestinationRegistry } from "src/interfaces/destinations/IDestinationRegistry.sol";
import { IDestinationVaultRegistry } from "src/interfaces/vault/IDestinationVaultRegistry.sol";

import { ILMPVaultFactory } from "src/interfaces/vault/ILMPVaultFactory.sol";
import { ILMPVaultRouter } from "src/interfaces/vault/ILMPVaultRouter.sol";

/// @notice Root most registry contract for the system
interface ISystemRegistry {
    /// @notice Get the LMP Vault registry for this system
    /// @return registry instance of the registry for this system
    function lmpVaultRegistry() external view returns (ILMPVaultRegistry registry);

    /// @notice Get the destination Vault registry for this system
    /// @return registry instance of the registry for this system
    function destinationVaultRegistry() external view returns (IDestinationVaultRegistry registry);

    /// @notice Get the access Controller for this system
    /// @return controller instance of the access controller for this system
    function accessController() external view returns (IAccessController controller);

    /// @notice Get the destination template registry for this system
    /// @return registry instance of the registry for this system
    function destinationTemplateRegistry() external view returns (IDestinationRegistry registry);

    /// @notice LMP Vault Router
    /// @return router instance of the lmp vault router
    function lmpVaultRouter() external view returns (ILMPVaultRouter router);

    /// @notice Vault factory lookup by type
    /// @return vaultFactory instance of the vault factory for this vault type
    function getLMPVaultFactoryByType(bytes32 vaultType) external view returns (ILMPVaultFactory vaultFactory);
}
