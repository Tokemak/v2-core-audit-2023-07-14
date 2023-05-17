// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ILMPVaultRegistry } from "./vault/ILMPVaultRegistry.sol";
import { IAccessController } from "./security/IAccessController.sol";
import { IDestinationRegistry } from "./destinations/IDestinationRegistry.sol";
import { IDestinationVaultRegistry } from "./vault/IDestinationVaultRegistry.sol";

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
}
