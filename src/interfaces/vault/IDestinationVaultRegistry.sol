// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISystemBound } from "src/interfaces/ISystemBound.sol";

/// @notice Tracks valid Destination Vaults for the system
interface IDestinationVaultRegistry is ISystemBound {
    /// @notice Determines if a given address is a valid Destination Vault in the system
    /// @param destinationVault address to check
    /// @return True if vault is registered
    function isRegistered(address destinationVault) external view returns (bool);

    /// @notice Registers a new Destination Vault
    /// @dev Should be locked down to only a factory
    /// @param newDestinationVault Address of the new vault
    function register(address newDestinationVault) external;
}
