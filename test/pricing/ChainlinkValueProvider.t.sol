// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { PRANK_ADDRESS } from "test/utils/Addresses.sol";

import { ChainlinkValueProvider } from "src/pricing/value-providers/ChainlinkValueProvider.sol";
import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { Errors } from "src/utils/Errors.sol";

contract ChainlinkValueProviderTest is Test {
    ChainlinkValueProvider public clValueProvider;

    event ChainlinkOracleSet(address token, address chainlinkOracle);
    event ChainlinkOracleRemoved(address token, address chainlinkOracle);

    function setUp() external {
        clValueProvider = new ChainlinkValueProvider(address(1));
    }

    // Test `addChainlinkOracle()`
    function test_RevertNonOwner() external {
        vm.prank(PRANK_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");

        clValueProvider.addChainlinkOracle(address(1), address(2));
    }

    function test_RevertZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenToAddOracle"));

        clValueProvider.addChainlinkOracle(address(0), address(1));
    }

    function test_RevertZeroAddressOracle() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "oracle"));

        clValueProvider.addChainlinkOracle(address(1), address(0));
    }

    function test_RevertOracleAlreadySet() external {
        clValueProvider.addChainlinkOracle(address(1), address(2));

        vm.expectRevert(Errors.MustBeZero.selector);

        clValueProvider.addChainlinkOracle(address(1), address(3));
    }

    function test_ProperAddOracle() external {
        vm.expectEmit(false, false, false, true);
        emit ChainlinkOracleSet(address(1), address(2));

        clValueProvider.addChainlinkOracle(address(1), address(2));

        assertEq(address(clValueProvider.getChainlinkOracle(address(1))), address(2));
    }

    // Test `removeChainlinkOracle()`
    function test_RevertZeroAddressToken() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenToRemoveOracle"));

        clValueProvider.removeChainlinkOracle(address(0));
    }

    function test_RevertOracleNotSet() external {
        vm.expectRevert(Errors.MustBeSet.selector);

        clValueProvider.removeChainlinkOracle(address(1));
    }

    function test_ProperRemoveOracle() external {
        clValueProvider.addChainlinkOracle(address(1), address(2));

        assertEq(address(clValueProvider.getChainlinkOracle(address(1))), address(2));

        vm.expectEmit(false, false, false, true);
        emit ChainlinkOracleRemoved(address(1), address(2));

        clValueProvider.removeChainlinkOracle(address(1));

        assertEq(address(clValueProvider.getChainlinkOracle(address(1))), address(0));
    }
}
