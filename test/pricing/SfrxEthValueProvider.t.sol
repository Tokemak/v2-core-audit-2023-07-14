// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { SFRXETH_MAINNET } from "../utils/Addresses.sol";

import { SfrxEthValueProvider } from "../../src/pricing/value-providers/SfrxEthValueProvider.sol";

contract SfrxEthValueProviderTest is Test {
    event SfrxEthSet(address sfrxEth);

    function test_Constructor() external {
        vm.expectEmit(false, false, false, true);
        emit SfrxEthSet(SFRXETH_MAINNET);

        SfrxEthValueProvider sfrxEthValueProvider = new SfrxEthValueProvider(SFRXETH_MAINNET, address(1));

        assertEq(address(sfrxEthValueProvider.sfrxEth()), SFRXETH_MAINNET);
    }

    function test_GetPrice() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        SfrxEthValueProvider sfrxEthValueProvider = new SfrxEthValueProvider(SFRXETH_MAINNET, address(1));

        vm.prank(address(1));
        assertGt(sfrxEthValueProvider.getPrice(address(0)), 0);
    }
}
