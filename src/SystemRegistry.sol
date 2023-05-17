// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { Ownable2Step } from "src/access/Ownable2Step.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { ILMPVaultRegistry } from "src/interfaces/vault/ILMPVaultRegistry.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";
import { IDestinationRegistry } from "src/interfaces/destinations/IDestinationRegistry.sol";
import { IDestinationVaultRegistry } from "src/interfaces/vault/IDestinationVaultRegistry.sol";

/// @notice Root contract of the system instance.
/// @dev All contracts in this instance of the system should be reachable from this contract
contract SystemRegistry is ISystemRegistry, Ownable2Step {
    /* ******************************** */
    /* State Variables                  */
    /* ******************************** */

    ILMPVaultRegistry private _lmpVaultRegistry;
    IDestinationVaultRegistry private _destinationVaultRegistry;
    IAccessController private _accessController;
    IDestinationRegistry private _destinationTemplateRegistry;

    /* ******************************** */
    /* Events                           */
    /* ******************************** */

    event LMPVaultRegistrySet(address newAddress);
    event DestinationVaultRegistrySet(address newAddress);
    event AccessControllerSet(address newAddress);
    event DestinationTemplateRegistrySet(address newAddress);

    /* ******************************** */
    /* Errors                           */
    /* ******************************** */

    error AlreadySet(string param);
    error SystemMismatch(address ours, address theirs);
    error InvalidContract(address addr);

    /* ******************************** */
    /* Views                            */
    /* ******************************** */

    /// @inheritdoc ISystemRegistry
    function lmpVaultRegistry() external view returns (ILMPVaultRegistry) {
        return _lmpVaultRegistry;
    }

    /// @inheritdoc ISystemRegistry
    function destinationVaultRegistry() external view returns (IDestinationVaultRegistry) {
        return _destinationVaultRegistry;
    }

    /// @inheritdoc ISystemRegistry
    function accessController() external view returns (IAccessController) {
        return _accessController;
    }

    /// @inheritdoc ISystemRegistry
    function destinationTemplateRegistry() external view returns (IDestinationRegistry) {
        return _destinationTemplateRegistry;
    }

    /* ******************************** */
    /* Function                         */
    /* ******************************** */

    /// @notice Set the LMP Vault Registry for this instance of the system
    /// @dev Should only be able to set this value one time
    /// @param registry Address of the registry
    function setLMPVaultRegistry(address registry) external onlyOwner {
        Errors.verifyNotZero(registry, "lmpVaultRegistry");

        if (address(_lmpVaultRegistry) != address(0)) {
            revert AlreadySet("lmpVaultRegistry");
        }

        emit LMPVaultRegistrySet(registry);

        _lmpVaultRegistry = ILMPVaultRegistry(registry);

        verifySystemsAgree(address(_lmpVaultRegistry));
    }

    /// @notice Set the Destination Vault Registry for this instance of the system
    /// @dev Should only be able to set this value one time
    /// @param registry Address of the registry
    function setDestinationVaultRegistry(address registry) external onlyOwner {
        Errors.verifyNotZero(registry, "destinationVaultRegistry");

        if (address(_destinationVaultRegistry) != address(0)) {
            revert AlreadySet("destinationVaultRegistry");
        }

        emit DestinationVaultRegistrySet(registry);

        _destinationVaultRegistry = IDestinationVaultRegistry(registry);

        verifySystemsAgree(address(_destinationVaultRegistry));
    }

    /// @notice Set the Access Controller for this instance of the system
    /// @dev Should only be able to set this value one time
    /// @param controller Address of the access controller
    function setAccessController(address controller) external onlyOwner {
        Errors.verifyNotZero(controller, "accessController");

        if (address(_accessController) != address(0)) {
            revert AlreadySet("accessController");
        }

        emit AccessControllerSet(controller);

        _accessController = IAccessController(controller);

        verifySystemsAgree(address(_accessController));
    }

    /// @notice Set the Destination Template Registry for this instance of the system
    /// @dev Should only be able to set this value one time
    /// @param registry Address of the registry
    function setDestinationTemplateRegistry(address registry) external onlyOwner {
        Errors.verifyNotZero(registry, "destinationTemplateRegistry");

        if (address(_destinationTemplateRegistry) != address(0)) {
            revert AlreadySet("destinationTemplateRegistry");
        }

        emit DestinationTemplateRegistrySet(registry);

        _destinationTemplateRegistry = IDestinationRegistry(registry);

        verifySystemsAgree(address(_destinationTemplateRegistry));
    }

    /// @notice Verifies that a system bound contract matches this contract
    /// @dev All system bound contracts must match a registry contract. Will revert on mismatch
    /// @param dep The contract to check
    function verifySystemsAgree(address dep) internal view {
        // slither-disable-start low-level-calls
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = dep.staticcall(abi.encodeWithSignature("getSystemRegistry()"));
        // slither-disable-end low-level-calls
        if (success) {
            address depRegistry = abi.decode(data, (address));
            if (depRegistry != address(this)) {
                revert SystemMismatch(address(this), depRegistry);
            }
        } else {
            revert InvalidContract(dep);
        }
    }
}
