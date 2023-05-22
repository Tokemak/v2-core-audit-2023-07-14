// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";
import { TELLOR_ORACLE } from "test/utils/Addresses.sol";

import { TellorValueProvider, Denominations } from "src/pricing/value-providers/TellorValueProvider.sol";
import { Errors } from "src/utils/errors.sol";

contract TellorValueProviderTest is Test {
    // Eth - usd query id
    bytes32 public constant QUERY_ID = 0x83a7f3d48786ac2667503a61e8c415438ed2922eb86a2906e4ee66d9a2ce4992;
    // 10k Eth, should never return higher as Eth has never cost this much at pinned blocks.
    uint256 public constant ETH_MAX_USD = 10_000_000_000_000_000_000_000;

    TellorValueProvider public tellorValueProviderLocal;

    event QueryIdSet(address token, bytes32 _queryId);
    event QueryIdRemoved(address token, bytes32 queryId);

    function setUp() external {
        tellorValueProviderLocal = new TellorValueProvider(address(1), address(2));
    }

    // Test `addQueryId()`.
    function test_RevertNonOwnerQueryId() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(3));

        tellorValueProviderLocal.addQueryId(address(1), bytes32("Test Bytes"));
    }

    function test_ZeroAddressRevert_AddQueryId() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenForQueryId"));

        tellorValueProviderLocal.addQueryId(address(0), bytes32("Test Bytes"));
    }

    function test_ZeroBytesRevert_AddQeuryId() external {
        vm.expectRevert(Errors.MustBeSet.selector);

        tellorValueProviderLocal.addQueryId(address(1), bytes32(0));
    }

    function test_RevertAlreadySet_AddQueryId() external {
        tellorValueProviderLocal.addQueryId(address(1), bytes32("Test Bytes"));

        vm.expectRevert(Errors.MustBeZero.selector);

        tellorValueProviderLocal.addQueryId(address(1), bytes32("Test Bytes 2"));
    }

    function test_ProperAddQueryId() external {
        vm.expectEmit(false, false, false, true);
        emit QueryIdSet(address(1), bytes32("Test Bytes"));

        tellorValueProviderLocal.addQueryId(address(1), bytes32("Test Bytes"));

        assertEq(tellorValueProviderLocal.getQueryId(address(1)), bytes32("Test Bytes"));
    }

    // Test `removeQueryId()`
    function test_RevertZeroAddressToken_RemoveQueryId() external {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "tokenToRemoveQueryId"));

        tellorValueProviderLocal.removeQueryId(address(0));
    }

    function test_QueryIdZeroBytes_RemoveQueryId() external {
        vm.expectRevert(Errors.MustBeSet.selector);

        tellorValueProviderLocal.removeQueryId(address(1));
    }

    function test_ProperRemoveQueryId() external {
        tellorValueProviderLocal.addQueryId(address(1), bytes32("Test Bytes"));

        assertEq(tellorValueProviderLocal.getQueryId(address(1)), bytes32("Test Bytes"));

        vm.expectEmit(false, false, false, true);
        emit QueryIdRemoved(address(1), bytes32("Test Bytes"));

        tellorValueProviderLocal.removeQueryId(address(1));

        assertEq(tellorValueProviderLocal.getQueryId(address(1)), bytes32(0));
    }

    // test `getPrice()`
    function test_GetPriceMainnet() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_100_000);

        TellorValueProvider mainnet = new TellorValueProvider(TELLOR_ORACLE, address(1));
        // Technically USD denomination, fine that it returns USD denomination as long as we know.
        mainnet.addDenomination(Denominations.ETH, Denominations.ETH);
        mainnet.addQueryId(Denominations.ETH, QUERY_ID);

        vm.prank(address(1));
        uint256 returnedPrice = mainnet.getPrice(Denominations.ETH);

        assertGt(returnedPrice, 0);
        assertLt(returnedPrice, ETH_MAX_USD);
    }

    function test_GetPriceOptimism() external {
        vm.createSelectFork(vm.envString("OPTIMISM_MAINNET_RPC_URL"), 90_000_000);

        TellorValueProvider optimism = new TellorValueProvider(TELLOR_ORACLE, address(1));
        optimism.addDenomination(Denominations.ETH, Denominations.ETH);
        optimism.addQueryId(Denominations.ETH, QUERY_ID);

        vm.prank(address(1));

        uint256 returnedPrice = optimism.getPrice(Denominations.ETH);

        assertGt(returnedPrice, 0);
        assertLt(returnedPrice, ETH_MAX_USD);
    }

    function test_GetPriceArbitrum() external {
        vm.createSelectFork(vm.envString("ARBITRUM_MAINNET_RPC_URL"), 80_000_000);

        TellorValueProvider arbitrum = new TellorValueProvider(TELLOR_ORACLE, address(1));
        arbitrum.addDenomination(Denominations.ETH, Denominations.ETH);
        arbitrum.addQueryId(Denominations.ETH, QUERY_ID);

        vm.prank(address(1));

        uint256 returnedPrice = arbitrum.getPrice(Denominations.ETH);

        assertGt(returnedPrice, 0);
        assertLt(returnedPrice, ETH_MAX_USD);
    }
}
