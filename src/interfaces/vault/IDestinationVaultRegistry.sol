// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice Tracks valid Destination Vaults for the system
interface IDestinationVaultRegistry {
    /// @notice Determines if a given address is a valid Destination Vault in the system
    /// @param destinationVault address to check
    /// @return True if valut is registered
    function isRegistered(address destinationVault) external returns (bool);
}
