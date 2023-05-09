// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { Errors } from "src/utils/errors.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { PRANK_ADDRESS, RANDOM } from "../utils/Addresses.sol";
import { DestinationRegistry } from "../../src/destinations/DestinationRegistry.sol";
import { IDestinationAdapter } from "../../src/interfaces/destinations/IDestinationAdapter.sol";
import { IDestinationRegistry } from "../../src/interfaces/destinations/IDestinationRegistry.sol";

contract DestinationRegistryTest is Test {
    DestinationRegistry public registry;

    event Register(bytes32[] indexed destinationTypes, address[] indexed targets);
    event Replace(bytes32[] indexed destinationTypes, address[] indexed targets);
    event Unregister(bytes32[] indexed destinationTypes);
    event Whitelist(bytes32[] indexed destinationTypes);
    event RemoveFromWhitelist(bytes32[] indexed destinationTypes);

    bytes32 private constant BALANCER_V2_META_STABLE_POOL_ADAPTER = keccak256("BalancerV2MetaStablePoolAdapter");
    bytes32 private constant CURVE_V2_FACTORY_CRYPTO_ADAPTER = keccak256("CurveV2FactoryCryptoAdapter");

    function setUp() public {
        registry = new DestinationRegistry(new SystemRegistry());
    }

    // Register
    function testRevertOnRegisteringMismatchedArrays() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](2);
        targets[0] = PRANK_ADDRESS;
        targets[1] = RANDOM;

        registry.addToWhitelist(destinationTypes);

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.ArraysLengthMismatch.selector));
        registry.register(destinationTypes, targets);
    }

    function testRevertOnRegisteringZeroAddress() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = address(0);

        registry.addToWhitelist(destinationTypes);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "target"));
        registry.register(destinationTypes, targets);
    }

    function testRevertOnRegisteringExistingDestination() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        registry.addToWhitelist(destinationTypes);
        registry.register(destinationTypes, targets);

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.DestinationAlreadySet.selector));
        registry.register(destinationTypes, targets);
    }

    function testRevertOnRegisteringNonWhitelistedDestination() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.NotAllowedDestination.selector));
        registry.register(destinationTypes, targets);
    }

    function testRegisterNewDestination() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        registry.addToWhitelist(destinationTypes);

        vm.expectEmit(true, true, false, true);
        emit Register(destinationTypes, targets);
        registry.register(destinationTypes, targets);
    }

    function testRegisterMultipleDestinations() public {
        bytes32[] memory destinationTypes = new bytes32[](2);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;
        destinationTypes[1] = CURVE_V2_FACTORY_CRYPTO_ADAPTER;

        address[] memory targets = new address[](2);
        targets[0] = PRANK_ADDRESS;
        targets[1] = RANDOM;

        registry.addToWhitelist(destinationTypes);

        vm.expectEmit(true, true, false, true);
        emit Register(destinationTypes, targets);
        registry.register(destinationTypes, targets);
    }

    // Replace
    function testRevertOnReplacingMismatchedArrays() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        registry.addToWhitelist(destinationTypes);

        registry.register(destinationTypes, targets);

        targets = new address[](2);
        targets[0] = PRANK_ADDRESS;
        targets[1] = RANDOM;

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.ArraysLengthMismatch.selector));
        registry.replace(destinationTypes, targets);
    }

    function testRevertOnReplacingToZeroAddress() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        registry.addToWhitelist(destinationTypes);

        registry.register(destinationTypes, targets);

        targets[0] = address(0);
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "target"));
        registry.replace(destinationTypes, targets);
    }

    function testRevertOnReplacingNonExistingDestination() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        registry.addToWhitelist(destinationTypes);

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.DestinationNotPresent.selector));
        registry.replace(destinationTypes, targets);
    }

    function testRevertOnReplacingToSameTarget() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        registry.addToWhitelist(destinationTypes);

        registry.register(destinationTypes, targets);

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.DestinationAlreadySet.selector));
        registry.replace(destinationTypes, targets);
    }

    function testReplaceExistingDestination() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        registry.addToWhitelist(destinationTypes);

        registry.register(destinationTypes, targets);

        targets[0] = RANDOM;
        vm.expectEmit(true, true, false, true);
        emit Replace(destinationTypes, targets);

        registry.replace(destinationTypes, targets);
    }

    // Unregister
    function testRevertOnUnregisteringNonExistingDestination() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        registry.addToWhitelist(destinationTypes);

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.DestinationNotPresent.selector));
        registry.unregister(destinationTypes);
    }

    function testUnregisterExistingDestination() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        registry.addToWhitelist(destinationTypes);

        registry.register(destinationTypes, targets);

        vm.expectEmit(true, true, false, true);
        emit Unregister(destinationTypes);

        registry.unregister(destinationTypes);
    }

    // Get adapter
    function testRevertOnGettingTargetForNonExistingDestination() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;
        registry.addToWhitelist(destinationTypes);

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.DestinationNotPresent.selector));
        registry.getAdapter(BALANCER_V2_META_STABLE_POOL_ADAPTER);
    }

    function testGetAdapterTargetForExistingDestination() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        registry.addToWhitelist(destinationTypes);

        registry.register(destinationTypes, targets);

        IDestinationAdapter result = registry.getAdapter(BALANCER_V2_META_STABLE_POOL_ADAPTER);

        assertEq(address(result), PRANK_ADDRESS);
    }

    // Add Destination Type to Whitelist
    function testRevertOnAddingExistingDestinationTypeToWhitelist() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        vm.expectEmit(true, true, false, true);
        emit Whitelist(destinationTypes);
        registry.addToWhitelist(destinationTypes);

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.DestinationAlreadySet.selector));
        registry.addToWhitelist(destinationTypes);
    }

    function testAddToDestinationTypeWhitelist() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        vm.expectEmit(true, true, false, true);
        emit Whitelist(destinationTypes);
        registry.addToWhitelist(destinationTypes);
    }

    function testAddMultipleToDestinationTypeWhitelist() public {
        bytes32[] memory destinationTypes = new bytes32[](2);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;
        destinationTypes[1] = CURVE_V2_FACTORY_CRYPTO_ADAPTER;

        vm.expectEmit(true, true, false, true);
        emit Whitelist(destinationTypes);
        registry.addToWhitelist(destinationTypes);
    }

    // Remove destination type from Whitelist
    function testRevertOnRemovingNonExistingDestinationTypeFromWhitelist() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        vm.expectEmit(true, true, false, true);
        emit Whitelist(destinationTypes);
        registry.addToWhitelist(destinationTypes);

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.DestinationNotPresent.selector));

        destinationTypes[0] = CURVE_V2_FACTORY_CRYPTO_ADAPTER;
        registry.removeFromWhitelist(destinationTypes);
    }

    function testRevertOnRemovingRegisteredDestinationTypeFromWhitelist() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        address[] memory targets = new address[](1);
        targets[0] = PRANK_ADDRESS;

        registry.addToWhitelist(destinationTypes);

        vm.expectEmit(true, true, false, true);
        emit Register(destinationTypes, targets);
        registry.register(destinationTypes, targets);

        vm.expectRevert(abi.encodeWithSelector(IDestinationRegistry.DestinationAlreadySet.selector));
        registry.removeFromWhitelist(destinationTypes);
    }

    function testRemoveFromDestinationTypeWhitelist() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        vm.expectEmit(true, true, false, true);
        emit Whitelist(destinationTypes);
        registry.addToWhitelist(destinationTypes);

        vm.expectEmit(true, true, false, true);
        emit RemoveFromWhitelist(destinationTypes);
        registry.removeFromWhitelist(destinationTypes);
    }

    function testRemoveMultipleFromDestinationTypeWhitelist() public {
        bytes32[] memory destinationTypes = new bytes32[](2);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;
        destinationTypes[1] = CURVE_V2_FACTORY_CRYPTO_ADAPTER;

        vm.expectEmit(true, true, false, true);
        emit Whitelist(destinationTypes);
        registry.addToWhitelist(destinationTypes);

        vm.expectEmit(true, true, false, true);
        emit RemoveFromWhitelist(destinationTypes);
        registry.removeFromWhitelist(destinationTypes);
    }

    // Check if destination type is in Whitelist
    function testIsWhitelistedDestination() public {
        bytes32[] memory destinationTypes = new bytes32[](1);
        destinationTypes[0] = BALANCER_V2_META_STABLE_POOL_ADAPTER;

        vm.expectEmit(true, true, false, true);
        emit Whitelist(destinationTypes);
        registry.addToWhitelist(destinationTypes);

        bool destinationIsWhitelisted = registry.isWhitelistedDestination(destinationTypes[0]);
        assert(destinationIsWhitelisted);
    }
}
