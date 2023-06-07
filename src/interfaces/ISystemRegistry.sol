// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IWETH9 } from "src/interfaces/utils/IWETH9.sol";
import { IGPToke } from "src/interfaces/staking/IGPToke.sol";
import { ILMPVaultRegistry } from "./vault/ILMPVaultRegistry.sol";
import { IAccessController } from "./security/IAccessController.sol";
import { ILMPVaultRouter } from "src/interfaces/vault/ILMPVaultRouter.sol";
import { ILMPVaultFactory } from "src/interfaces/vault/ILMPVaultFactory.sol";
import { IDestinationRegistry } from "./destinations/IDestinationRegistry.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";
import { ILMPVaultRegistry } from "src/interfaces/vault/ILMPVaultRegistry.sol";
import { IDestinationVaultRegistry } from "./vault/IDestinationVaultRegistry.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";
import { IDestinationRegistry } from "src/interfaces/destinations/IDestinationRegistry.sol";
import { IStatsCalculatorRegistry } from "src/interfaces/stats/IStatsCalculatorRegistry.sol";
import { IDestinationVaultRegistry } from "src/interfaces/vault/IDestinationVaultRegistry.sol";

/// @notice Root most registry contract for the system
interface ISystemRegistry {
    /// @notice Get the TOKE contract for the system
    /// @return toke instance of TOKE used in the system
    function toke() external view returns (IERC20Metadata toke);

    /// @notice Get the referenced WETH contract for the system
    /// @return weth contract pointer
    function weth() external view returns (IWETH9 weth);

    /// @notice Get the GPToke staking contract
    /// @return gpToke instance of the gpToke contract for the system
    function gpToke() external view returns (IGPToke);

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

    /// @notice Get the stats calculator registry for this system
    /// @return registry instance of the registry for this system
    function statsCalculatorRegistry() external view returns (IStatsCalculatorRegistry registry);

    /// @notice Get the root price oracle for this system
    /// @return oracle instance of the root price oracle for this system
    function rootPriceOracle() external view returns (IRootPriceOracle oracle);
}
