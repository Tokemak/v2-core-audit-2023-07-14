// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISystemBound } from "src/interfaces/ISystemBound.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";

/// @notice Creates and registers Destination Vaults for the system
interface IDestinationVaultFactory is ISystemBound {
    /// @notice Creates a vault of the specified type
    /// @dev vaultType will be bytes32 encoded and checked that a template is registered
    /// @param vaultType human readable key of the vault template
    /// @param baseAsset Base asset of the system. WETH/USDC/etc
    /// @param proxyName Name of the DEX pool this vault proxies
    /// @param params params to be passed to vaults initialize function
    function create(
        string memory vaultType,
        address baseAsset,
        string memory proxyName,
        bytes memory params
    ) external;
}
