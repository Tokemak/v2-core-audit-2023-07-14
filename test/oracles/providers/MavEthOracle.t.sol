// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { WETH9_ADDRESS, TOKE_MAINNET, WSTETH_MAINNET } from "test/utils/Addresses.sol";

import { MavEthOracle } from "src/oracles/providers/MavEthOracle.sol";
import { SystemRegistry, ISystemRegistry } from "src/SystemRegistry.sol";
import { RootPriceOracle } from "src/oracles/RootPriceOracle.sol";
import { AccessController, IAccessController } from "src/security/AccessController.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { Errors } from "src/utils/Errors.sol";

// solhint-disable func-name-mixedcase

contract MavEthOracleTest is Test {
    event MaxTotalBinWidthSet(uint256 newMaxBinWidth);

    SystemRegistry public registry;
    AccessController public accessControl;
    RootPriceOracle public rootOracle;
    MavEthOracle public mavOracle;

    function setUp() external {
        registry = new SystemRegistry(TOKE_MAINNET, WETH9_ADDRESS);
        accessControl = new AccessController(address(registry));
        registry.setAccessController(address(accessControl));
        rootOracle = new RootPriceOracle(registry);
        registry.setRootPriceOracle(address(rootOracle));
        mavOracle = new MavEthOracle(registry);
    }

    // Constructor tests
    function test_RevertSystemRegistryZeroAddress() external {
        // Reverts with generic evm revert.
        vm.expectRevert();
        new MavEthOracle(ISystemRegistry(address(0)));
    }

    function test_RevertRootPriceOracleZeroAddress() external {
        // Doesn't have root oracle set.
        SystemRegistry localSystemRegistry = new SystemRegistry(TOKE_MAINNET, WETH9_ADDRESS);
        AccessController localAccessControl = new AccessController(address(localSystemRegistry));
        localSystemRegistry.setAccessController(address(localAccessControl));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "priceOracle"));
        new MavEthOracle(ISystemRegistry(address(localSystemRegistry)));
    }

    function test_ProperlySetsState() external {
        assertEq(mavOracle.getSystemRegistry(), address(registry));
    }

    // Test setMaxTotalBinWidth
    function test_OnlyOwner() external {
        vm.prank(address(1));
        vm.expectRevert(IAccessController.AccessDenied.selector);

        mavOracle.setMaxTotalBinWidth(60);
    }

    function test_RevertZero() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidParam.selector, "_maxTotalbinWidth"));

        mavOracle.setMaxTotalBinWidth(0);
    }

    function test_ProperlySetsMax() external {
        vm.expectEmit(false, false, false, true);
        emit MaxTotalBinWidthSet(60);

        mavOracle.setMaxTotalBinWidth(60);
        assertEq(mavOracle.maxTotalBinWidth(), 60);
    }

    // Test getPriceInEth
    function test_RevertZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "_boostedPosition"));

        mavOracle.getPriceInEth(address(0));
    }
}
