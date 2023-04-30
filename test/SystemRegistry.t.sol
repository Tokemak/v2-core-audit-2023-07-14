// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import { Errors } from "src/utils/Errors.sol";
import { Test, StdCheats } from "forge-std/Test.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { ISystemBound } from "src/interfaces/ISystemBound.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";
import { ILMPVaultRegistry } from "src/interfaces/vault/ILMPVaultRegistry.sol";
import { IDestinationRegistry } from "src/interfaces/destinations/IDestinationRegistry.sol";
import { IDestinationVaultRegistry } from "src/interfaces/vault/IDestinationVaultRegistry.sol";

contract SystemRegistryTest is Test {
    SystemRegistry private _systemRegistry;

    event LMPVaultRegistrySet(address newAddress);
    event AccessControllerSet(address newAddress);
    event DestinationVaultRegistrySet(address newAddress);
    event DestinationTemplateRegistrySet(address newAddress);

    function setUp() public {
        _systemRegistry = new SystemRegistry();
    }

    /* ******************************** */
    /* LMP Vault Registry
    /* ******************************** */

    function testSystemRegistryLMPVaultSetOnceDuplicateValue() public {
        address lmpVault = vm.addr(1);
        mockSystemBound(lmpVault);
        _systemRegistry.setLMPVaultRegistry(lmpVault);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "lmpVaultRegistry"));
        _systemRegistry.setLMPVaultRegistry(lmpVault);
    }

    function testSystemRegistryLMPVaultSetOnceDifferentValue() public {
        address lmpVault = vm.addr(1);
        mockSystemBound(lmpVault);
        _systemRegistry.setLMPVaultRegistry(lmpVault);
        lmpVault = vm.addr(2);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "lmpVaultRegistry"));
        _systemRegistry.setLMPVaultRegistry(lmpVault);
    }

    function testSystemRegistryLMPVaultZeroNotAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "lmpVaultRegistry"));
        _systemRegistry.setLMPVaultRegistry(address(0));
    }

    function testSystemRegistryLMPVaultRetrieveSetValue() public {
        address lmpVault = vm.addr(3);
        mockSystemBound(lmpVault);
        _systemRegistry.setLMPVaultRegistry(lmpVault);
        ILMPVaultRegistry queried = _systemRegistry.lmpVaultRegistry();

        assertEq(lmpVault, address(queried));
    }

    function testSystemRegistryLMPVaultEmitsEventWithNewAddress() public {
        address lmpVault = vm.addr(3);

        vm.expectEmit(true, true, true, true);
        emit LMPVaultRegistrySet(lmpVault);

        mockSystemBound(lmpVault);
        _systemRegistry.setLMPVaultRegistry(lmpVault);
    }

    function testSystemRegistryLMPVaultOnlyCallableByOwner() public {
        address lmpVault = vm.addr(3);
        address newOwner = vm.addr(4);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(newOwner);
        _systemRegistry.setLMPVaultRegistry(lmpVault);
    }

    function testSystemRegistryLMPVaultSystemsMatch() public {
        address lmpVault = vm.addr(1);
        address fakeRegistry = vm.addr(2);
        vm.mockCall(lmpVault, abi.encodeWithSelector(ISystemBound.systemRegistry.selector), abi.encode(fakeRegistry));
        vm.expectRevert(
            abi.encodeWithSelector(SystemRegistry.SystemMismatch.selector, address(_systemRegistry), fakeRegistry)
        );
        _systemRegistry.setLMPVaultRegistry(lmpVault);
    }

    /* ******************************** */
    /* Destination Vault Registry
    /* ******************************** */

    function testSystemRegistryDestinationVaultSetOnceDuplicateValue() public {
        address destinationVault = vm.addr(1);
        mockSystemBound(destinationVault);
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "destinationVaultRegistry"));
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
    }

    function testSystemRegistryDestinationVaultSetOnceDifferentValue() public {
        address destinationVault = vm.addr(1);
        mockSystemBound(destinationVault);
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
        destinationVault = vm.addr(2);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "destinationVaultRegistry"));
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
    }

    function testSystemRegistryDestinationVaultZeroNotAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "destinationVaultRegistry"));
        _systemRegistry.setDestinationVaultRegistry(address(0));
    }

    function testSystemRegistryDestinationVaultRetrieveSetValue() public {
        address destinationVault = vm.addr(3);
        mockSystemBound(destinationVault);
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
        IDestinationVaultRegistry queried = _systemRegistry.destinationVaultRegistry();

        assertEq(destinationVault, address(queried));
    }

    function testSystemRegistryDestinationVaultEmitsEventWithNewAddress() public {
        address destinationVault = vm.addr(3);

        vm.expectEmit(true, true, true, true);
        emit DestinationVaultRegistrySet(destinationVault);

        mockSystemBound(destinationVault);
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
    }

    function testSystemRegistryDestinationVaultOnlyCallableByOwner() public {
        address destinationVault = vm.addr(3);
        address newOwner = vm.addr(4);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(newOwner);
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
    }

    function testSystemRegistryDestinationVaultSystemsMatch() public {
        address destinationVault = vm.addr(1);
        address fakeRegistry = vm.addr(2);
        vm.mockCall(
            destinationVault, abi.encodeWithSelector(ISystemBound.systemRegistry.selector), abi.encode(fakeRegistry)
        );
        vm.expectRevert(
            abi.encodeWithSelector(SystemRegistry.SystemMismatch.selector, address(_systemRegistry), fakeRegistry)
        );
        _systemRegistry.setDestinationVaultRegistry(destinationVault);
    }

    /* ******************************** */
    /* Destination Template Registry
    /* ******************************** */

    function testSystemRegistryDestinationTemplateSetOnceDuplicateValue() public {
        address destinationTemplate = vm.addr(1);
        mockSystemBound(destinationTemplate);
        _systemRegistry.setDestinationTemplateRegistry(destinationTemplate);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "destinationTemplateRegistry"));
        _systemRegistry.setDestinationTemplateRegistry(destinationTemplate);
    }

    function testSystemRegistryDestinationTemplateSetOnceDifferentValue() public {
        address destinationTemplate = vm.addr(1);
        mockSystemBound(destinationTemplate);
        _systemRegistry.setDestinationTemplateRegistry(destinationTemplate);
        destinationTemplate = vm.addr(2);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "destinationTemplateRegistry"));
        _systemRegistry.setDestinationTemplateRegistry(destinationTemplate);
    }

    function testSystemRegistryDestinationTemplateZeroNotAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "destinationTemplateRegistry"));
        _systemRegistry.setDestinationTemplateRegistry(address(0));
    }

    function testSystemRegistryDestinationTemplateRetrieveSetValue() public {
        address destinationTemplate = vm.addr(3);
        mockSystemBound(destinationTemplate);
        _systemRegistry.setDestinationTemplateRegistry(destinationTemplate);
        IDestinationRegistry queried = _systemRegistry.destinationTemplateRegistry();

        assertEq(destinationTemplate, address(queried));
    }

    function testSystemRegistryDestinationTemplateEmitsEventWithNewAddress() public {
        address destinationTemplate = vm.addr(3);

        vm.expectEmit(true, true, true, true);
        emit DestinationTemplateRegistrySet(destinationTemplate);

        mockSystemBound(destinationTemplate);
        _systemRegistry.setDestinationTemplateRegistry(destinationTemplate);
    }

    function testSystemRegistryDestinationTemplateOnlyCallableByOwner() public {
        address destinationTemplate = vm.addr(3);
        address newOwner = vm.addr(4);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(newOwner);
        _systemRegistry.setDestinationTemplateRegistry(destinationTemplate);
    }

    function testSystemRegistryDestinationTemplateSystemsMatch() public {
        address destinationTemplate = vm.addr(1);
        address fakeRegistry = vm.addr(2);
        vm.mockCall(
            destinationTemplate, abi.encodeWithSelector(ISystemBound.systemRegistry.selector), abi.encode(fakeRegistry)
        );
        vm.expectRevert(
            abi.encodeWithSelector(SystemRegistry.SystemMismatch.selector, address(_systemRegistry), fakeRegistry)
        );
        _systemRegistry.setDestinationTemplateRegistry(destinationTemplate);
    }

    /* ******************************** */
    /* Access Controller
    /* ******************************** */

    function testSystemRegistryAccessControllerVaultSetOnceDuplicateValue() public {
        address accessController = vm.addr(1);
        mockSystemBound(accessController);
        _systemRegistry.setAccessController(accessController);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "accessController"));
        _systemRegistry.setAccessController(accessController);
    }

    function testSystemRegistryAccessControllerVaultSetOnceDifferentValue() public {
        address accessController = vm.addr(1);
        mockSystemBound(accessController);
        _systemRegistry.setAccessController(accessController);
        accessController = vm.addr(2);
        vm.expectRevert(abi.encodeWithSelector(SystemRegistry.AlreadySet.selector, "accessController"));
        _systemRegistry.setAccessController(accessController);
    }

    function testSystemRegistryAccessControllerVaultZeroNotAllowed() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "accessController"));
        _systemRegistry.setAccessController(address(0));
    }

    function testSystemRegistryAccessControllerVaultRetrieveSetValue() public {
        address accessController = vm.addr(3);
        mockSystemBound(accessController);
        _systemRegistry.setAccessController(accessController);
        IAccessController queried = _systemRegistry.accessController();

        assertEq(accessController, address(queried));
    }

    function testSystemRegistryAccessControllerEmitsEventWithNewAddress() public {
        address accessController = vm.addr(3);

        vm.expectEmit(true, true, true, true);
        emit AccessControllerSet(accessController);

        mockSystemBound(accessController);
        _systemRegistry.setAccessController(accessController);
    }

    function testSystemRegistryAccessControllerOnlyCallableByOwner() public {
        address accessController = vm.addr(3);
        address newOwner = vm.addr(4);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(newOwner);
        _systemRegistry.setAccessController(accessController);
    }

    function testSystemRegistryAccessControllerSystemsMatch() public {
        address accessController = vm.addr(1);
        address fakeRegistry = vm.addr(2);
        vm.mockCall(
            accessController, abi.encodeWithSelector(ISystemBound.systemRegistry.selector), abi.encode(fakeRegistry)
        );
        vm.expectRevert(
            abi.encodeWithSelector(SystemRegistry.SystemMismatch.selector, address(_systemRegistry), fakeRegistry)
        );
        _systemRegistry.setAccessController(accessController);
    }

    /* ******************************** */
    /* Helpers
    /* ******************************** */

    function mockSystemBound(address addr) internal {
        vm.mockCall(addr, abi.encodeWithSelector(ISystemBound.systemRegistry.selector), abi.encode(_systemRegistry));
    }
}
