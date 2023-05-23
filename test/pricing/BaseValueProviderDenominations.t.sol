// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { PRANK_ADDRESS, WETH_MAINNET } from "test/utils/Addresses.sol";

import {
    BaseValueProviderDenominations,
    BaseValueProvider
} from "src/pricing/value-providers/base/BaseValueProviderDenominations.sol";
import { ChainlinkValueProvider } from "src/pricing/value-providers/ChainlinkValueProvider.sol";
import { Errors } from "src/utils/Errors.sol";

contract BaseValueProviderDenominationsTest is Test {
    BaseValueProviderDenominations public baseDenominationsProvider;

    event TokenDenominationSet(address token, address denomination);
    event TokenDenominationRemoved(address token, address denomination);

    function setUp() external {
        ChainlinkValueProvider clValueProvider = new ChainlinkValueProvider(address(1));
        baseDenominationsProvider = BaseValueProviderDenominations(address(clValueProvider));
    }

    // Test `addDenomination()`
    function test_RevertNonOwner_AddDenomination() external {
        vm.prank(PRANK_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");

        baseDenominationsProvider.addDenomination(WETH_MAINNET, address(1));
    }

    function test_RevertZeroAddressToken_AddDenomination() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenToDenominate"));
        baseDenominationsProvider.addDenomination(address(0), address(1));
    }

    function test_RevertZeroAddressDenomination_AddDenomination() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "denomination"));
        baseDenominationsProvider.addDenomination(address(1), address(0));
    }

    function test_RevertDenominationAlreadySet_AddDenomination() external {
        baseDenominationsProvider.addDenomination(address(1), address(2));

        vm.expectRevert(Errors.MustBeZero.selector);
        baseDenominationsProvider.addDenomination(address(1), address(3));
    }

    function test_ProperAdd() external {
        vm.expectEmit(false, false, false, true);
        emit TokenDenominationSet(address(1), address(2));

        baseDenominationsProvider.addDenomination(address(1), address(2));

        assertEq(baseDenominationsProvider.getDenomination(address(1)), address(2));
    }

    // Test `removeDenomination()`
    function test_RevertZeroAddressToken_RemoveDenomination() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenWithDenomination"));
        baseDenominationsProvider.removeDenomination(address(0));
    }

    function test_MustBeSet_RemoveValueProvider() external {
        vm.expectRevert(Errors.MustBeSet.selector);
        baseDenominationsProvider.removeDenomination(address(1));
    }

    function test_ProperRemoveDenomination() external {
        baseDenominationsProvider.addDenomination(address(1), address(2));

        assertEq(baseDenominationsProvider.getDenomination(address(1)), address(2));

        vm.expectEmit(false, false, false, true);
        emit TokenDenominationRemoved(address(1), address(2));

        baseDenominationsProvider.removeDenomination(address(1));

        assertEq(baseDenominationsProvider.getDenomination(address(1)), address(0));
    }
}
