// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { PRANK_ADDRESS } from "test/utils/Addresses.sol";

import { EthValueOracle, IEthValueOracle, TokemakPricingPrecision } from "src/pricing/EthValueOracle.sol";
import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { Errors } from "src/utils/errors.sol";

contract EthValueOracleUnitTest is Test {
    EthValueOracle public ethValueOracle;

    event ValueProviderAdded(address token, address valueProvider);
    event ValueProviderRemoved(address token, address valueProvider);

    function setUp() external {
        ethValueOracle = new EthValueOracle();
    }

    // Test `addValueProvider()`
    function test_RevertNonOwner() external {
        vm.prank(PRANK_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");

        ethValueOracle.addValueProvider(address(1), address(2));
    }

    function test_RevertZeroAddressToken_AddValueProvider() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenToPrice"));
        ethValueOracle.addValueProvider(address(0), address(1));
    }

    function test_RevertZeroAddressValueProvider_AddValueProvider() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "valueProvider"));
        ethValueOracle.addValueProvider(address(1), address(0));
    }

    function test_RevertAlreadySet_AddValueProvider() external {
        ethValueOracle.addValueProvider(address(1), address(2));

        vm.expectRevert(Errors.MustBeZero.selector);
        ethValueOracle.addValueProvider(address(1), address(3));
    }

    function test_ProperAdd() external {
        vm.expectEmit(false, false, false, true);
        emit ValueProviderAdded(address(1), address(2));

        ethValueOracle.addValueProvider(address(1), address(2));
        assertEq(address(ethValueOracle.valueProviderByToken(address(1))), address(2));
    }

    // test `removeValueProvider()`
    function test_RevertZeroAddress_RemoveValueProvider() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenToPrice"));

        ethValueOracle.removeValueProvider(address(0));
    }

    function test_RevertNotSet_RemoveValueProvider() external {
        vm.expectRevert(Errors.MustBeSet.selector);

        ethValueOracle.removeValueProvider(address(1));
    }

    function test_ProperRemoval() external {
        ethValueOracle.addValueProvider(address(1), address(2));

        vm.expectEmit(false, false, false, true);
        emit ValueProviderRemoved(address(1), address(2));

        ethValueOracle.removeValueProvider(address(1));
        assertEq(address(ethValueOracle.valueProviderByToken(address(1))), address(0));
    }

    // `getPrice()` unit tests

    function test_RevertZeroAmountGetPrice() external {
        vm.expectRevert(IEthValueOracle.CannotBeZeroAmount.selector);
        ethValueOracle.getPrice(address(1), 0, true);
    }

    function test_RevertZeroAddressGetPrice() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "valueProvider"));
        ethValueOracle.getPrice(address(1), TokemakPricingPrecision.STANDARD_PRECISION, true);
    }
}
