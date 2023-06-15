// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { SWETH_MAINNET } from "test/utils/Addresses.sol";

import { SwEthEthOracle } from "src/oracles/providers/SwEthEthOracle.sol";
import { Errors } from "src/utils/Errors.sol";

import { IswETH } from "src/interfaces/external/swell/IswETH.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";

contract SwEthEthOracleTest is Test {
    SwEthEthOracle public swEthOracle;

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_400_000);
        swEthOracle = new SwEthEthOracle(ISystemRegistry(address(1)), IswETH(SWETH_MAINNET));
    }

    // Test constructor
    function test_RevertsConstructor() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "_systemRegistry"));
        new SwEthEthOracle(ISystemRegistry(address(0)), IswETH(SWETH_MAINNET));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "_swEth"));
        new SwEthEthOracle(ISystemRegistry(address(1)), IswETH(address(0)));
    }

    function test_StateVariablesSetConstructor() external {
        assertEq(address(swEthOracle.systemRegistry()), address(1));
        assertEq(address(swEthOracle.swEth()), SWETH_MAINNET);
    }

    // Test pricing functionality
    function test_RevertNotSwEth() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidToken.selector, address(2)));
        swEthOracle.getPriceInEth(address(2));
    }

    function test_GetPriceInEth() external {
        uint256 price = swEthOracle.getPriceInEth(SWETH_MAINNET);
        assertGt(price, 0);
    }

    // Test get system registry
    function test_GetSystemRegistry() external {
        assertEq(address(swEthOracle.getSystemRegistry()), address(1));
    }
}
