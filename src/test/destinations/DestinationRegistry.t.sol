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

    event Register(bytes32 indexed destination, address indexed target);
    event Replace(bytes32 indexed destination, address indexed target);
    event Unregister(bytes32 indexed destination, address indexed target);

    function setUp() public {
        registry = new DestinationRegistry();
    }

    // Register
    function testRevertOnRegisteringZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.ZeroAddress.selector, bytes("target")));
        registry.register(keccak256("BalancerV2MetaStablePoolAdapter"), address(0));
    }

    function testRevertOnRegisteringExistingDestination() public {
        registry.register(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.DestinationAlreadySet.selector));
        registry.register(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);
    }

    function testRegisterNewDestination() public {
        vm.expectEmit(true, true, false, true);
        emit Register(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);
        registry.register(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);
    }

    // Replace
    function testRevertOnReplacingToZeroAddress() public {
        registry.register(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.ZeroAddress.selector, bytes("target")));
        registry.replace(keccak256("BalancerV2MetaStablePoolAdapter"), address(0));
    }

    function testRevertOnReplacingNonExistingDestination() public {
        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.DestinationNotPresent.selector));
        registry.replace(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);
    }

    function testRevertOnReplacingToSameTarget() public {
        registry.register(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);

        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.DestinationAlreadySet.selector));
        registry.replace(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);
    }

    function testReplaceExistingDestination() public {
        registry.register(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);

        vm.expectEmit(true, true, false, true);
        emit Replace(keccak256("BalancerV2MetaStablePoolAdapter"), RANDOM);

        registry.replace(keccak256("BalancerV2MetaStablePoolAdapter"), RANDOM);
    }

    // Unregister
    function testRevertOnUnregisteringNonExistingDestination() public {
        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.DestinationNotPresent.selector));
        registry.unregister(keccak256("BalancerV2MetaStablePoolAdapter"));
    }

    function testUnregisterExistingDestination() public {
        registry.register(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);

        vm.expectEmit(true, true, false, true);
        emit Unregister(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);

        registry.unregister(keccak256("BalancerV2MetaStablePoolAdapter"));
    }

    // Get adapter
    function testRevertOnGettingTargetForNonExistingDestination() public {
        vm.expectRevert(abi.encodeWithSelector(DestinationRegistry.DestinationNotPresent.selector));
        registry.getAdapter(keccak256("BalancerV2MetaStablePoolAdapter"));
    }

    function testGetAdapterTargetForExistingDestination() public {
        registry.register(keccak256("BalancerV2MetaStablePoolAdapter"), PRANK_ADDRESS);

        IDestinationAdapter result = registry.getAdapter(keccak256("BalancerV2MetaStablePoolAdapter"));

        assertEq(address(result), PRANK_ADDRESS);
    }
}
