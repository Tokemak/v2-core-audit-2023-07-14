// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

// solhint-disable func-name-mixedcase

import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { BalancerUtilities } from "src/libs/BalancerUtilities.sol";
import { WSETH_RETH_SFRXETH_BAL_POOL, WSETH_WETH_BAL_POOL } from "test/utils/Addresses.sol";

contract BalancerUtilitiesTest is Test {
    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
    }

    function test_isComposablePool_ReturnsTrueOnValidComposable() public {
        assertTrue(BalancerUtilities.isComposablePool(WSETH_RETH_SFRXETH_BAL_POOL));
    }

    function test_isComposablePool_ReturnsFalseOnMetastable() public {
        assertFalse(BalancerUtilities.isComposablePool(WSETH_WETH_BAL_POOL));
    }

    function test_isComposablePool_ReturnsFalseOnEOA() public {
        assertFalse(BalancerUtilities.isComposablePool(vm.addr(5)));
    }

    function test_isComposablePool_ReturnsFalseOnInvalidContract() public {
        assertFalse(BalancerUtilities.isComposablePool(address(new Noop())));
    }
}

contract Noop { }
