// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { PRANK_ADDRESS } from "../utils/Addresses.sol";

import { ChainlinkValueProvider } from "../../src/pricing/value-providers/ChainlinkValueProvider.sol";
import { BaseValueProvider } from "../../src/pricing/value-providers/base/BaseValueProvider.sol";

contract ChainlinkValueProviderTest is Test {
    ChainlinkValueProvider public clValueProvider;

    event ChainlinkOracleSet(address token, address chainlinkOracle);

    function setUp() external {
        clValueProvider = new ChainlinkValueProvider(address(1));
    }

    // Test `setChainlinkOracle()`
    function test_RevertNonOwner() external {
        vm.prank(PRANK_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");

        clValueProvider.setChainlinkOracle(address(1), address(2));
    }

    function test_RevertZeroAddress() external {
        vm.expectRevert(BaseValueProvider.CannotBeZeroAddress.selector);
        clValueProvider.setChainlinkOracle(address(0), address(1));
    }

    function test_ProperAddOracle() external {
        vm.expectEmit(false, false, false, true);
        emit ChainlinkOracleSet(address(1), address(2));

        clValueProvider.setChainlinkOracle(address(1), address(2));

        assertEq(address(clValueProvider.getChainlinkOracle(address(1))), address(2));
    }

    function test_ProperRemoveOracle() external {
        clValueProvider.setChainlinkOracle(address(1), address(2));

        assertEq(address(clValueProvider.getChainlinkOracle(address(1))), address(2));

        vm.expectEmit(false, false, false, true);
        emit ChainlinkOracleSet(address(1), address(0));

        clValueProvider.setChainlinkOracle(address(1), address(0));

        assertEq(address(clValueProvider.getChainlinkOracle(address(1))), address(0));
    }
}
