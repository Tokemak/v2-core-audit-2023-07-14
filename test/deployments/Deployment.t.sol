// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { Test, StdCheats } from "forge-std/Test.sol";

import { SystemRegistry } from "src/SystemRegistry.sol";
import { AccessController } from "src/security/AccessController.sol";
import { DestinationVaultRegistry } from "src/vault/DestinationVaultRegistry.sol";
import { ILMPVaultRegistry } from "src/interfaces/vault/ILMPVaultRegistry.sol";
import { IDestinationVaultRegistry } from "src/interfaces/vault/IDestinationVaultRegistry.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";

contract DeploymentTest is Test {
    address public owner;
    SystemRegistry private _systemRegistry;
    AccessController private _accessController;
    DestinationVaultRegistry private _destinationVaultRegistry;

    function setUp() public {
        _systemRegistry = new SystemRegistry();
        _accessController = new AccessController(address(_systemRegistry));

        _systemRegistry.setAccessController(address(_accessController));

        _destinationVaultRegistry = new DestinationVaultRegistry(_systemRegistry);

        _systemRegistry.setDestinationVaultRegistry(address(_destinationVaultRegistry));
    }

    function testInitialDeployment() public { }
}
