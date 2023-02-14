// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { PRANK_ADDRESS } from "../utils/Addresses.sol";

import { EthValueOracle, IEthValueOracle, TokemakPricingPrecision } from "../../src/pricing/EthValueOracle.sol";
import { BaseValueProvider } from "../../src/pricing/value-providers/base/BaseValueProvider.sol";

contract EthValueOracleUnitTest is Test {
    EthValueOracle public ethValueOracle;

    event ValueProviderUpdated(address token, address valueProvider);

    function setUp() external {
        ethValueOracle = new EthValueOracle();
    }

    // Test `updateValueProvider()`

    function test_RevertNonOwner() external {
        vm.prank(PRANK_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");

        ethValueOracle.updateValueProvider(address(1), address(2));
    }

    function test_RevertZeroAddressUpdateValueProvider() external {
        vm.expectRevert(BaseValueProvider.CannotBeZeroAddress.selector);
        ethValueOracle.updateValueProvider(address(0), address(1));
    }

    function test_ProperAdd() external {
        vm.expectEmit(false, false, false, true);
        emit ValueProviderUpdated(address(1), address(2));

        ethValueOracle.updateValueProvider(address(1), address(2));
        assertEq(address(ethValueOracle.valueProviderByToken(address(1))), address(2));
    }

    function test_ProperRemoval() external {
        ethValueOracle.updateValueProvider(address(1), address(2));

        assertEq(address(ethValueOracle.valueProviderByToken(address(1))), address(2));

        vm.expectEmit(false, false, false, false);
        emit ValueProviderUpdated(address(1), address(0));

        ethValueOracle.updateValueProvider(address(1), address(0));

        assertEq(address(ethValueOracle.valueProviderByToken(address(1))), address(0));
    }

    // `getPrice()` unit tests

    function test_RevertZeroAmountGetPrice() external {
        vm.expectRevert(IEthValueOracle.CannotBeZeroAmount.selector);
        ethValueOracle.getPrice(address(1), 0, true);
    }

    function test_RevertZeroAddressGetPrice() external {
        vm.expectRevert(BaseValueProvider.CannotBeZeroAddress.selector);
        ethValueOracle.getPrice(address(1), TokemakPricingPrecision.STANDARD_PRECISION, true);
    }
}
