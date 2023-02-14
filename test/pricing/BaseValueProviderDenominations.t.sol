// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { PRANK_ADDRESS, WETH_MAINNET } from "../utils/Addresses.sol";

import {
    BaseValueProviderDenominations,
    BaseValueProvider
} from "../../src/pricing/value-providers/base/BaseValueProviderDenominations.sol";
import { ChainlinkValueProvider } from "../../src/pricing/value-providers/ChainlinkValueProvider.sol";

contract BaseValueProviderDenominationsTest is Test {
    BaseValueProviderDenominations public baseDenominationsProvider;

    event TokenDenominationSet(address token, address denomination);

    function setUp() external {
        ChainlinkValueProvider clValueProvider = new ChainlinkValueProvider(address(1));
        baseDenominationsProvider = BaseValueProviderDenominations(address(clValueProvider));
    }

    // Test `setDenomination()`
    function test_RevertNonOwner() external {
        vm.prank(PRANK_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");

        baseDenominationsProvider.setDenomination(WETH_MAINNET, address(1));
    }

    function test_RevertZeroAddress() external {
        vm.expectRevert(BaseValueProvider.CannotBeZeroAddress.selector);
        baseDenominationsProvider.setDenomination(address(0), address(1));
    }

    function test_ProperAddDenomination() external {
        vm.expectEmit(false, false, false, true);
        emit TokenDenominationSet(address(1), address(2));

        baseDenominationsProvider.setDenomination(address(1), address(2));

        assertEq(baseDenominationsProvider.getDenomination(address(1)), address(2));
    }

    function test_ProperRemoveDenomination() external {
        baseDenominationsProvider.setDenomination(address(1), address(2));

        assertEq(baseDenominationsProvider.getDenomination(address(1)), address(2));

        vm.expectEmit(false, false, false, true);
        emit TokenDenominationSet(address(1), address(0));

        baseDenominationsProvider.setDenomination(address(1), address(0));

        assertEq(baseDenominationsProvider.getDenomination(address(1)), address(0));
    }
}
