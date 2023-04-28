// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { Test, StdCheats } from "forge-std/Test.sol";

import { SystemRegistry } from "src/SystemRegistry.sol";
import { IPlasmaVaultRegistry } from "src/interfaces/vault/IPlasmaVaultRegistry.sol";
import { IDestinationVaultRegistry } from "src/interfaces/vault/IDestinationVaultRegistry.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";

contract SystemRegistryTest is Test {
    address public owner;
    SystemRegistry private _systemRegistry;

    event LMPVaultRegistrySet(address newAddress);
    event DestinationVaultRegistrySet(address newAddress);
    event AccessControllerSet(address newAddress);

    function setUp() public {
        _systemRegistry = new SystemRegistry();
    }

    /* ******************************** */
    /* LMP Vault Registry 
    /* ******************************** */

    function testSystemRegistryLMPVaultSetOnceDuplicateValue() public {
        address lmpVault = vm.addr(1);
        _systemRegistry.setLMPVaultRegistry(lmpVault);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "lmpVaultRegistry"));
        _systemRegistry.setLMPVaultRegistry(lmpVault);
    }

    function testSystemRegistryLMPVaultSetOnceDifferentValue() public {
        address lmpVault = vm.addr(1);
        _systemRegistry.setLMPVaultRegistry(lmpVault);
        lmpVault = vm.addr(2);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "lmpVaultRegistry"));
        _systemRegistry.setLMPVaultRegistry(lmpVault);
    }

    function testSystemRegistryLMPVaultZeroNotAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.ZeroAddress.selector, "lmpVaultRegistry"));
        _systemRegistry.setLMPVaultRegistry(address(0));
    }

    function testSystemRegistryLMPVaultRetrieveSetValue() public {
        address lmpVault = vm.addr(3);
        _systemRegistry.setLMPVaultRegistry(lmpVault);
        IPlasmaVaultRegistry queried = _systemRegistry.lmpVaultRegistry();

        assertEq(lmpVault, address(queried));
    }

    function testSystemRegistryLMPVaultEmitsEventWithNewAddress() public {
        address lmpVault = vm.addr(3);

        vm.expectEmit(true, true, true, true);
        emit LMPVaultRegistrySet(lmpVault);

        _systemRegistry.setLMPVaultRegistry(lmpVault);
    }

    function testSystemRegistryLMPVaultOnlyCallableByOwner() public {
        address lmpVault = vm.addr(3);
        address newOwner = vm.addr(4);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(newOwner);
        _systemRegistry.setLMPVaultRegistry(lmpVault);
    }

    /* ******************************** */
    /* Destination Vault Registry
    /* ******************************** */

    function testSystemRegistryDestinationVaultSetOnceDuplicateValue() public {
        address destinationVault = vm.addr(1);
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "destinationVaultRegistry"));
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
    }

    function testSystemRegistryDestinationVaultSetOnceDifferentValue() public {
        address destinationVault = vm.addr(1);
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
        destinationVault = vm.addr(2);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "destinationVaultRegistry"));
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
    }

    function testSystemRegistryDestinationVaultZeroNotAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.ZeroAddress.selector, "destinationVaultRegistry"));
        _systemRegistry.setDestinationVaultRegistry(address(0));
    }

    function testSystemRegistryDestinationVaultRetrieveSetValue() public {
        address destinationVault = vm.addr(3);
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
        IDestinationVaultRegistry queried = _systemRegistry.destinationVaultRegistry();

        assertEq(destinationVault, address(queried));
    }

    function testSystemRegistryDestinationVaultEmitsEventWithNewAddress() public {
        address destinationVault = vm.addr(3);

        vm.expectEmit(true, true, true, true);
        emit DestinationVaultRegistrySet(destinationVault);

        _systemRegistry.setDestinationVaultRegistry(destinationVault);
    }

    function testSystemRegistryDestinationVaultOnlyCallableByOwner() public {
        address destinationVault = vm.addr(3);
        address newOwner = vm.addr(4);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(newOwner);
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
    }

    /* ******************************** */
    /* Access Controller
    /* ******************************** */

    function testSystemRegistryAccessControllerVaultSetOnceDuplicateValue() public {
        address accessController = vm.addr(1);
        _systemRegistry.setAccessController(accessController);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "accessController"));
        _systemRegistry.setAccessController(accessController);
    }

    function testSystemRegistryAccessControllerVaultSetOnceDifferentValue() public {
        address accessController = vm.addr(1);
        _systemRegistry.setAccessController(accessController);
        accessController = vm.addr(2);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "accessController"));
        _systemRegistry.setAccessController(accessController);
    }

    function testSystemRegistryAccessControllerVaultZeroNotAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.ZeroAddress.selector, "accessController"));
        _systemRegistry.setAccessController(address(0));
    }

    function testSystemRegistryAccessControllerVaultRetrieveSetValue() public {
        address accessController = vm.addr(3);
        _systemRegistry.setAccessController(accessController);
        IAccessController queried = _systemRegistry.accessController();

        assertEq(accessController, address(queried));
    }

    function testSystemRegistryAccessControllerEmitsEventWithNewAddress() public {
        address accessController = vm.addr(3);

        vm.expectEmit(true, true, true, true);
        emit AccessControllerSet(accessController);

        _systemRegistry.setAccessController(accessController);
    }

    function testSystemRegistryAccessControllerOnlyCallableByOwner() public {
        address accessController = vm.addr(3);
        address newOwner = vm.addr(4);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(newOwner);
        _systemRegistry.setAccessController(accessController);
    }
}
