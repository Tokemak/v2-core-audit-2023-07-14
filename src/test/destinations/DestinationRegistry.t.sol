// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "ds-test/test.sol";
import "../../destinations/DestinationRegistry.sol";
import "../../interfaces/destinations/IDestinationRegistry.sol";
import "../../interfaces/destinations/IDestinationAdapter.sol";
import { Hevm } from "../interfaces/Hevm.sol";
import { PRANK_ADDRESS, RANDOM, HEVM_ADDRESS } from "../utils/Addresses.sol";

contract DestinationRegistryTest is DSTest {
    Hevm private vm = Hevm(HEVM_ADDRESS);

    DestinationRegistry public registry;

    event Register(IDestinationRegistry.DestinationType indexed destination, address indexed target);
    event Replace(IDestinationRegistry.DestinationType indexed destination, address indexed target);
    event Unregister(IDestinationRegistry.DestinationType indexed destination, address indexed target);

    function setUp() public {
        registry = new DestinationRegistry();
    }

    // Register
    function testRevertOnRegisteringZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.ZeroAddress.selector, bytes("target")));
        registry.register((IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter), address(0));
    }

    function testRevertOnRegisteringExistingDestination() public {
        registry.register((IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter), PRANK_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.DestinationAlreadySet.selector));
        registry.register((IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter), PRANK_ADDRESS);
    }

    function testRegisterNewDestination() public {
        vm.expectEmit(true, true, false, true);
        emit Register(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, PRANK_ADDRESS);
        registry.register(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, PRANK_ADDRESS);
    }

    // Replace
    function testRevertOnReplacingToZeroAddress() public {
        registry.register(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, PRANK_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.ZeroAddress.selector, bytes("target")));
        registry.replace((IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter), address(0));
    }

    function testRevertOnReplacingNonExistingDestination() public {
        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.DestinationNotPresent.selector));
        registry.replace(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, PRANK_ADDRESS);
    }

    function testRevertOnReplacingToSameTarget() public {
        registry.register(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, PRANK_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.DestinationAlreadySet.selector));
        registry.replace(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, PRANK_ADDRESS);
    }

    function testReplaceExistingDestination() public {
        registry.register(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, PRANK_ADDRESS);

        vm.expectEmit(true, true, false, true);
        emit Replace(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, RANDOM);

        registry.replace(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, RANDOM);
    }

    // Unregister
    function testRevertOnUnregisteringNonExistingDestination() public {
        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.DestinationNotPresent.selector));
        registry.unregister(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter);
    }

    function testUnregisterExistingDestination() public {
        registry.register(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, PRANK_ADDRESS);

        vm.expectEmit(true, true, false, true);
        emit Unregister(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, PRANK_ADDRESS);

        registry.unregister(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter);
    }

    // Get adapter
    function testRevertOnGettingTargetForNonExistingDestination() public {
        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.DestinationNotPresent.selector));
        registry.getAdapter(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter);
    }

    function testGetAdapterTargetForExistingDestination() public {
        registry.register(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter, PRANK_ADDRESS);

        IDestinationAdapter result =
            registry.getAdapter(IDestinationRegistry.DestinationType.BalancerV2MetaStablePoolAdapter);

        assertEq(address(result), PRANK_ADDRESS);
    }
}
