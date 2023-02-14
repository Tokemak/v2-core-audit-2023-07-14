// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { PRANK_ADDRESS } from "../utils/Addresses.sol";

import { BaseValueProvider } from "../../src/pricing/value-providers/base/BaseValueProvider.sol";
import { VelodromeValueProvider } from "../../src/pricing/value-providers/VelodromeValueProvider.sol";

contract BaseValueProviderTest is Test {
    BaseValueProvider public baseValueProvider;

    event EthValueOracleSet(address ethValueOracle);

    function setUp() external {
        // Using VelodromeValueProvider to deploy BaseValueProvider, access functionality.
        VelodromeValueProvider veloValueProvider = new VelodromeValueProvider(address(1));
        baseValueProvider = BaseValueProvider(address(veloValueProvider));
    }

    // Constructor args
    function test_EthValueOracleAddressIsSetAfterConstruction() external {
        assertTrue(baseValueProvider.ethValueOracle.address != address(0));
    }

    // `setEthValueOracle` function
    function test_RevertNonOwner() external {
        vm.prank(PRANK_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");
        baseValueProvider.setEthValueOracle(address(2));
    }

    function test_RevertZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(BaseValueProvider.CannotBeZeroAddress.selector));
        baseValueProvider.setEthValueOracle(address(0));
    }

    function test_ProperOperation() external {
        vm.expectEmit(false, false, false, true);
        emit EthValueOracleSet(address(2));

        baseValueProvider.setEthValueOracle(address(2));
        assertEq(address(baseValueProvider.ethValueOracle()), address(2));
    }
}
