// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { ROCKET_ETH_OVM_ORACLE } from "test/utils/Addresses.sol";

import { OptimismRocketPoolEthValueProvider } from "src/pricing/value-providers/OptimismRocketPoolEthValueProvider.sol";

contract OptimismRocketPoolEthValueProviderTest is Test {
    event RocketOvmOracleSet(address rocketOvmOracle);

    function test_Constructor() external {
        vm.expectEmit(false, false, false, true);
        emit RocketOvmOracleSet(ROCKET_ETH_OVM_ORACLE);
        OptimismRocketPoolEthValueProvider rEthValueProvider =
            new OptimismRocketPoolEthValueProvider(ROCKET_ETH_OVM_ORACLE, address(1));

        assertEq(address(rEthValueProvider.rocketOvmOracle()), ROCKET_ETH_OVM_ORACLE);
    }

    function test_GetPrice() external {
        vm.createSelectFork(vm.envString("OPTIMISM_MAINNET_RPC_URL"));

        OptimismRocketPoolEthValueProvider rEthValueProvider =
            new OptimismRocketPoolEthValueProvider(ROCKET_ETH_OVM_ORACLE, address(1));

        vm.prank(address(1));
        assertGt(rEthValueProvider.getPrice(address(0)), 0);
    }
}
