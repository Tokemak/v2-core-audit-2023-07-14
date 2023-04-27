// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPlasmaVaultRegistry } from "./vault/IPlasmaVaultRegistry.sol";
import { IDestinationVaultRegistry } from "./vault/IDestinationVaultRegistry.sol";
import { IAccessController } from "./security/IAccessController.sol";

/// @notice Root most registry contract for the system
interface ISystemRegistry {
    /// @notice LMP Vault registry for the system
    /// @return registry instance of the registry for this system
    function lmpVaultRegistry() external view returns (IPlasmaVaultRegistry registry);

    /// @notice Destination Vault registry for the system
    /// @return registry instance of the registry for this system
    function destinationVaultRegistry() external view returns (IDestinationVaultRegistry registry);

    /// @notice Access Controller for the system
    /// @return controller instance of the access controller for this system
    function accessController() external view returns (IAccessController controller);
}
