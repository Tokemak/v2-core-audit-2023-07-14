// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable2Step } from "./access/Ownable2Step.sol";
import { ISystemRegistry } from "./interfaces/ISystemRegistry.sol";
import { IAccessController } from "./interfaces/security/IAccessController.sol";
import { IPlasmaVaultRegistry } from "./interfaces/vault/IPlasmaVaultRegistry.sol";
import { IDestinationVaultRegistry } from "./interfaces/vault/IDestinationVaultRegistry.sol";

/// @notice Root contract of the system instance.
/// @dev All contracts in this instance of the system should be reachable from this contract
contract SystemRegistry is ISystemRegistry, Ownable2Step {
    /* ******************************** */
    /* State Variables                  */
    /* ******************************** */

    address private _lmpVaultRegistry;
    address private _destinationVaultRegistry;
    address private _accessController;

    /* ******************************** */
    /* Events                           */
    /* ******************************** */

    event LMPVaultRegistrySet(address newAddress);
    event DestinationVaultRegistrySet(address newAddress);
    event AccessControllerSet(address newAddress);

    /* ******************************** */
    /* Errors                           */
    /* ******************************** */

    error ZeroAddress(string param);
    error AlreadySet(string param);

    /* ******************************** */
    /* Views                            */
    /* ******************************** */

    /// @inheritdoc ISystemRegistry
    function lmpVaultRegistry() external view returns (IPlasmaVaultRegistry registry) {
        registry = IPlasmaVaultRegistry(_lmpVaultRegistry);
    }

    /// @inheritdoc ISystemRegistry
    function destinationVaultRegistry() external view returns (IDestinationVaultRegistry registry) {
        registry = IDestinationVaultRegistry(_destinationVaultRegistry);
    }

    /// @inheritdoc ISystemRegistry
    function accessController() external view returns (IAccessController controller) {
        controller = IAccessController(_accessController);
    }

    /* ******************************** */
    /* Function                         */
    /* ******************************** */

    /// @notice Retrieve the LMP Vault Registry for this instance of the system
    /// @dev Should only be able to set this value one time
    /// @param registry Address of the registry
    function setLMPVaultRegistry(address registry) external onlyOwner {
        if (registry == address(0)) {
            revert ZeroAddress("lmpVaultRegistry");
        }
        if (_lmpVaultRegistry != address(0)) {
            revert AlreadySet("lmpVaultRegistry");
        }

        emit LMPVaultRegistrySet(registry);

        _lmpVaultRegistry = registry;
    }

    /// @notice Retrieve the Destination Vault Registry for this instance of the system
    /// @dev Should only be able to set this value one time
    /// @param registry Address of the registry
    function setDestinationVaultRegistry(address registry) external onlyOwner {
        if (registry == address(0)) {
            revert ZeroAddress("destinationVaultRegistry");
        }
        if (_destinationVaultRegistry != address(0)) {
            revert AlreadySet("destinationVaultRegistry");
        }

        emit DestinationVaultRegistrySet(registry);

        _destinationVaultRegistry = registry;
    }

    /// @notice Retrieve the Access Controller for this instance of the system
    /// @dev Should only be able to set this value one time
    /// @param controller Address of the access controller
    function setAccessController(address controller) external onlyOwner {
        if (controller == address(0)) {
            revert ZeroAddress("accessController");
        }
        if (_accessController != address(0)) {
            revert AlreadySet("accessController");
        }

        emit AccessControllerSet(controller);

        _accessController = controller;
    }
}
