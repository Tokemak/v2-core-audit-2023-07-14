// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { PRANK_ADDRESS, RETH_MAINNET, RETH_CL_FEED_MAINNET } from "test/utils/Addresses.sol";

import { ChainlinkValueProvider } from "src/pricing/value-providers/ChainlinkValueProvider.sol";
import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { BaseValueProviderDenominations } from "src/pricing/value-providers/base/BaseValueProviderDenominations.sol";
import { Errors } from "src/utils/Errors.sol";

import { IAggregatorV3Interface } from "src/interfaces/external/chainlink/IAggregatorV3Interface.sol";

contract ChainlinkValueProviderTest is Test {
    ChainlinkValueProvider public clValueProvider;

    event ChainlinkRegistrationAdded(
        address token, address chainlinkOracle, BaseValueProviderDenominations.Denomination, uint8 decimals
    );
    event ChainlinkRegistrationRemoved(address token, address chainlinkOracle);

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        clValueProvider = new ChainlinkValueProvider(address(1));
    }

    // Test `registerChainlinkOracle()`
    function test_RevertNonOwner() external {
        vm.prank(PRANK_ADDRESS);
        vm.expectRevert("Ownable: caller is not the owner");

        clValueProvider.registerChainlinkOracle(
            RETH_MAINNET, IAggregatorV3Interface(RETH_CL_FEED_MAINNET), BaseValueProviderDenominations.Denomination.ETH
        );
    }

    function test_RevertZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenToAddOracle"));

        clValueProvider.registerChainlinkOracle(
            address(0), IAggregatorV3Interface(RETH_CL_FEED_MAINNET), BaseValueProviderDenominations.Denomination.ETH
        );
    }

    function test_RevertZeroAddressOracle() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "oracle"));

        clValueProvider.registerChainlinkOracle(
            RETH_MAINNET, IAggregatorV3Interface(address(0)), BaseValueProviderDenominations.Denomination.ETH
        );
    }

    function test_RevertOracleAlreadySet() external {
        clValueProvider.registerChainlinkOracle(
            RETH_MAINNET, IAggregatorV3Interface(RETH_CL_FEED_MAINNET), BaseValueProviderDenominations.Denomination.ETH
        );

        vm.expectRevert(Errors.MustBeZero.selector);

        clValueProvider.registerChainlinkOracle(
            RETH_MAINNET, IAggregatorV3Interface(RETH_CL_FEED_MAINNET), BaseValueProviderDenominations.Denomination.ETH
        );
    }

    function test_ProperAddOracle() external {
        vm.expectEmit(false, false, false, true);
        emit ChainlinkRegistrationAdded(
            RETH_MAINNET, RETH_CL_FEED_MAINNET, BaseValueProviderDenominations.Denomination.ETH, 18
        );

        clValueProvider.registerChainlinkOracle(
            RETH_MAINNET, IAggregatorV3Interface(RETH_CL_FEED_MAINNET), BaseValueProviderDenominations.Denomination.ETH
        );

        ChainlinkValueProvider.ChainlinkInfo memory clInfo = clValueProvider.getChainlinkInfo(RETH_MAINNET);
        assertEq(address(clInfo.oracle), RETH_CL_FEED_MAINNET);
        assertEq(uint8(clInfo.denomination), uint8(BaseValueProviderDenominations.Denomination.ETH));
        assertEq(clInfo.decimals, IAggregatorV3Interface(RETH_CL_FEED_MAINNET).decimals());
    }

    // Test `removeChainlinkRegistration()`
    function test_RevertZeroAddressToken() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenToRemoveOracle"));

        clValueProvider.removeChainlinkRegistration(address(0));
    }

    function test_RevertOracleNotSet() external {
        vm.expectRevert(Errors.MustBeSet.selector);

        clValueProvider.removeChainlinkRegistration(RETH_MAINNET);
    }

    function test_ProperRemoveOracle() external {
        clValueProvider.registerChainlinkOracle(
            RETH_MAINNET, IAggregatorV3Interface(RETH_CL_FEED_MAINNET), BaseValueProviderDenominations.Denomination.ETH
        );

        assertEq(address(clValueProvider.getChainlinkInfo(RETH_MAINNET).oracle), RETH_CL_FEED_MAINNET);

        vm.expectEmit(false, false, false, true);
        emit ChainlinkRegistrationRemoved(RETH_MAINNET, RETH_CL_FEED_MAINNET);

        clValueProvider.removeChainlinkRegistration(RETH_MAINNET);

        assertEq(address(clValueProvider.getChainlinkInfo(RETH_MAINNET).oracle), address(0));
    }
}
