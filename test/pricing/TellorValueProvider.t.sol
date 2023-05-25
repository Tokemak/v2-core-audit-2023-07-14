// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { TELLOR_ORACLE, RETH_MAINNET, RETH_CL_FEED_MAINNET } from "test/utils/Addresses.sol";

import {
    TellorValueProvider,
    Denominations,
    BaseValueProviderDenominations
} from "src/pricing/value-providers/TellorValueProvider.sol";
import { Errors } from "src/utils/Errors.sol";

contract TellorValueProviderTest is Test {
    // Eth - usd query id
    bytes32 public constant QUERY_ID = 0x83a7f3d48786ac2667503a61e8c415438ed2922eb86a2906e4ee66d9a2ce4992;
    // 10k Eth, should never return higher as Eth has never cost this much at pinned blocks.
    uint256 public constant ETH_MAX_USD = 10_000_000_000_000_000_000_000;

    TellorValueProvider public tellorValueProviderLocal;

    event TellorRegistrationAdded(address token, BaseValueProviderDenominations.Denomination, bytes32 _queryId);
    event TellorRegistrationRemoved(address token, bytes32 queryId);

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        tellorValueProviderLocal = new TellorValueProvider(address(1), address(2));
    }

    // Test `addTellorRegistration()`.
    function test_RevertNonOwnerQueryId() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(3));

        tellorValueProviderLocal.addTellorRegistration(
            address(1), bytes32("Test Bytes"), BaseValueProviderDenominations.Denomination.ETH
        );
    }

    function test_ZeroAddressRevert_AddTellorRegistration() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenForQueryId"));

        tellorValueProviderLocal.addTellorRegistration(
            address(0), bytes32("Test Bytes"), BaseValueProviderDenominations.Denomination.ETH
        );
    }

    function test_ZeroBytesRevert_AddTellorRegistration() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidParam.selector, "queryId"));

        tellorValueProviderLocal.addTellorRegistration(
            address(1), bytes32(0), BaseValueProviderDenominations.Denomination.ETH
        );
    }

    function test_RevertAlreadySet_AddTellorRegistration() external {
        tellorValueProviderLocal.addTellorRegistration(
            address(1), bytes32("Test Bytes"), BaseValueProviderDenominations.Denomination.ETH
        );

        vm.expectRevert(Errors.MustBeZero.selector);

        tellorValueProviderLocal.addTellorRegistration(
            address(1), bytes32("Test Bytes 2"), BaseValueProviderDenominations.Denomination.ETH
        );
    }

    function test_ProperAddTellorRegistration() external {
        vm.expectEmit(false, false, false, true);
        emit TellorRegistrationAdded(address(1), BaseValueProviderDenominations.Denomination.ETH, bytes32("Test Byte"));

        tellorValueProviderLocal.addTellorRegistration(
            address(1), bytes32("Test Byte"), BaseValueProviderDenominations.Denomination.ETH
        );

        assertEq(tellorValueProviderLocal.getQueryInfo(address(1)).queryId, bytes32("Test Byte"));
    }

    // Test `removeTellorRegistration()`
    function test_RevertZeroAddressToken_RemoveTellorRegistration() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenToRemoveRegistration"));

        tellorValueProviderLocal.removeTellorRegistration(address(0));
    }

    function test_QueryIdZeroBytes_RemoveTellorRegistration() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidParam.selector, "queryIdBeforeDeletion"));

        tellorValueProviderLocal.removeTellorRegistration(address(1));
    }

    function test_ProperRemoveTellorRegistration() external {
        tellorValueProviderLocal.addTellorRegistration(
            address(1), bytes32("Test Bytes"), BaseValueProviderDenominations.Denomination.ETH
        );

        assertEq(tellorValueProviderLocal.getQueryInfo(address(1)).queryId, bytes32("Test Bytes"));

        vm.expectEmit(false, false, false, true);
        emit TellorRegistrationRemoved(address(1), bytes32("Test Bytes"));

        tellorValueProviderLocal.removeTellorRegistration(address(1));

        assertEq(tellorValueProviderLocal.getQueryInfo(address(1)).queryId, bytes32(0));
    }

    // test `getPrice()`
    function test_GetPriceMainnet() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_100_000);

        TellorValueProvider mainnet = new TellorValueProvider(TELLOR_ORACLE, address(1));
        mainnet.addTellorRegistration(Denominations.ETH, QUERY_ID, BaseValueProviderDenominations.Denomination.ETH);

        vm.prank(address(1));
        uint256 returnedPrice = mainnet.getPrice(Denominations.ETH);

        assertGt(returnedPrice, 0);
        assertLt(returnedPrice, ETH_MAX_USD);
    }

    function test_GetPriceOptimism() external {
        vm.createSelectFork(vm.envString("OPTIMISM_MAINNET_RPC_URL"), 90_000_000);

        TellorValueProvider optimism = new TellorValueProvider(TELLOR_ORACLE, address(1));
        optimism.addTellorRegistration(Denominations.ETH, QUERY_ID, BaseValueProviderDenominations.Denomination.ETH);

        vm.prank(address(1));

        uint256 returnedPrice = optimism.getPrice(Denominations.ETH);

        assertGt(returnedPrice, 0);
        assertLt(returnedPrice, ETH_MAX_USD);
    }

    function test_GetPriceArbitrum() external {
        vm.createSelectFork(vm.envString("ARBITRUM_MAINNET_RPC_URL"), 80_000_000);

        TellorValueProvider arbitrum = new TellorValueProvider(TELLOR_ORACLE, address(1));
        arbitrum.addTellorRegistration(Denominations.ETH, QUERY_ID, BaseValueProviderDenominations.Denomination.ETH);

        vm.prank(address(1));

        uint256 returnedPrice = arbitrum.getPrice(Denominations.ETH);

        assertGt(returnedPrice, 0);
        assertLt(returnedPrice, ETH_MAX_USD);
    }
}
