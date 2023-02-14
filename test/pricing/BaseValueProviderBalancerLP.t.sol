// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { BAL_VAULT, PRANK_ADDRESS } from "../utils/Addresses.sol";

import {
    BaseValueProviderBalancerLP,
    BaseValueProvider
} from "../../src/pricing/value-providers/base/BaseValueProviderBalancerLP.sol";
import { BalancerV2LPValueProvider } from "../../src/pricing/value-providers/BalancerV2LPValueProvider.sol";

contract BaseValueProviderBalancerLPTest is Test {
    BaseValueProviderBalancerLP public baseBalancerProvider;

    event BalancerVaultSet(address balancerVault);

    function setUp() external {
        // Using balancer value provider to deploy BaseBalancerValueProvider, access functionality.
        BalancerV2LPValueProvider balValueProvider = new BalancerV2LPValueProvider(BAL_VAULT, address(1));
        baseBalancerProvider = BaseValueProviderBalancerLP(address(balValueProvider));
    }

    // Constructor test
    function test_BalancerVaultSetDuringContruction() external {
        assertEq(address(baseBalancerProvider.balancerVault()), BAL_VAULT);
    }

    // Test `setBalancerVault()`
    function test_RevertNonOwner() external {
        vm.prank(PRANK_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");
        baseBalancerProvider.setBalancerVault(PRANK_ADDRESS);
    }

    function test_RevertZeroAddress() external {
        vm.expectRevert(BaseValueProvider.CannotBeZeroAddress.selector);
        baseBalancerProvider.setBalancerVault(address(0));
    }

    function test_ProperOperation() external {
        vm.expectEmit(false, false, false, true);
        emit BalancerVaultSet(address(1));

        baseBalancerProvider.setBalancerVault(address(1));
        assertEq(address(baseBalancerProvider.balancerVault()), address(1));
    }
}
