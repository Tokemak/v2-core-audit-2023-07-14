// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Test } from "forge-std/Test.sol";
import { Roles } from "src/libs/Roles.sol";
import { Errors } from "src/utils/Errors.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { IAccessController, AccessController } from "src/security/AccessController.sol";
import { BeaconChainBacking } from "src/beacon/BeaconChainBacking.sol";
import { IBeaconChainBacking } from "src/interfaces/beacon/IBeaconChainBacking.sol";
import { PRANK_ADDRESS, RANDOM, TOKE_MAINNET, WETH_MAINNET, FRXETH_MAINNET } from "test/utils/Addresses.sol";

import { BaseTest } from "test/BaseTest.t.sol";

contract BeaconChainBackingTest is Test {
    AccessController private accessController;
    BeaconChainBacking private beaconBaking;

    event RatioUpdated(uint208 ratio, uint48 timestamp);

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        vm.label(address(this), "testContract");

        SystemRegistry systemRegistry = new SystemRegistry(vm.addr(100), WETH_MAINNET);

        accessController = new AccessController(address(systemRegistry));
        accessController.grantRole(Roles.LSD_BACKING_UPDATER, address(this));

        systemRegistry.setAccessController(address(accessController));

        beaconBaking = new BeaconChainBacking(systemRegistry, FRXETH_MAINNET);
    }

    function testUpdateRatio() public {
        uint208 totalAssets = 90;
        uint208 totalLiabilities = 10;
        uint48 queriedTimestamp = 999;

        uint208 expectedRatio = 9_000_000_000_000_000_000;

        vm.expectEmit(true, true, true, true);
        emit RatioUpdated(expectedRatio, queriedTimestamp);

        beaconBaking.update(totalAssets, totalLiabilities, queriedTimestamp);

        (uint208 ratio, uint48 timestamp) = beaconBaking.current();

        assertEq(expectedRatio, ratio);
        assertEq(queriedTimestamp, timestamp);
    }

    function testRevertOnUpdateRatioWithoutRole() public {
        accessController.revokeRole(Roles.LSD_BACKING_UPDATER, address(this));

        uint208 totalAssets = 90;
        uint208 totalLiabilities = 10;
        uint48 queriedTimestamp = 999;

        vm.expectRevert();
        beaconBaking.update(totalAssets, totalLiabilities, queriedTimestamp);
    }

    function testRevertOnUpdateRatioWhenTimestampIsLessThanCurrent() public {
        uint208 totalAssets = 90;
        uint208 totalLiabilities = 10;
        uint48 queriedTimestamp = 999;

        beaconBaking.update(totalAssets, totalLiabilities, queriedTimestamp);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidParam.selector, "queriedTimestamp"));
        beaconBaking.update(totalAssets, totalLiabilities, queriedTimestamp - 1);
    }
}
