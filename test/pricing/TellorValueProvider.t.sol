// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";

import { TellorValueProvider, Denominations } from "../../src/pricing/value-providers/TellorValueProvider.sol";
import { TELLOR_ORACLE } from "../utils/Addresses.sol";

contract TellorValueProviderTest is Test {
    // Eth - usd query id
    bytes32 public constant QUERY_ID = 0x83a7f3d48786ac2667503a61e8c415438ed2922eb86a2906e4ee66d9a2ce4992;
    // 10k Eth, should never return higher as Eth has never cost this much at pinned blocks.
    uint256 public constant ETH_MAX_USD = 10_000_000_000_000_000_000_000;

    TellorValueProvider public tellorValueProviderLocal;

    error CannotBeZeroAddress();

    event QueryIdSet(address token, bytes32 _queryId);

    function setUp() external {
        tellorValueProviderLocal = new TellorValueProvider(address(1), address(2));
    }

    // Test `setQueryId()`.
    function test_RevertNonOwnerQueryId() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(3));

        tellorValueProviderLocal.setQueryId(address(1), bytes32("Test Bytes"));
    }

    function test_ZeroAddressRevert() external {
        vm.expectRevert(CannotBeZeroAddress.selector);

        tellorValueProviderLocal.setQueryId(address(0), bytes32("Test Bytes"));
    }

    function test_ProperSetQueryId() external {
        vm.expectEmit(false, false, false, true);
        emit QueryIdSet(address(1), bytes32("Test Bytes"));

        tellorValueProviderLocal.setQueryId(address(1), bytes32("Test Bytes"));

        assertEq(tellorValueProviderLocal.getQueryId(address(1)), bytes32("Test Bytes"));
    }

    function test_ProperRemoveQueryId() external {
        tellorValueProviderLocal.setQueryId(address(1), bytes32("Test Bytes"));

        assertEq(tellorValueProviderLocal.getQueryId(address(1)), bytes32("Test Bytes"));

        vm.expectEmit(false, false, false, true);
        emit QueryIdSet(address(1), bytes32(0));

        tellorValueProviderLocal.setQueryId(address(1), bytes32(0));

        assertEq(tellorValueProviderLocal.getQueryId(address(1)), bytes32(0));
    }

    // test `getPrice()`
    function test_GetPriceMainnet() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17_100_000);

        TellorValueProvider mainnet = new TellorValueProvider(TELLOR_ORACLE, address(1));
        // Technically USD denomination, fine that it returns USD denomination as long as we know.
        mainnet.setDenomination(Denominations.ETH, Denominations.ETH);
        mainnet.setQueryId(Denominations.ETH, QUERY_ID);

        vm.prank(address(1));
        uint256 returnedPrice = mainnet.getPrice(Denominations.ETH);

        assertGt(returnedPrice, 0);
        assertLt(returnedPrice, ETH_MAX_USD);
    }

    function test_GetPriceOptimism() external {
        vm.createSelectFork(vm.envString("OPTIMISM_MAINNET_RPC_URL"), 90_000_000);

        TellorValueProvider optimism = new TellorValueProvider(TELLOR_ORACLE, address(1));
        optimism.setDenomination(Denominations.ETH, Denominations.ETH);
        optimism.setQueryId(Denominations.ETH, QUERY_ID);

        vm.prank(address(1));

        uint256 returnedPrice = optimism.getPrice(Denominations.ETH);

        assertGt(returnedPrice, 0);
        assertLt(returnedPrice, ETH_MAX_USD);
    }

    function test_GetPriceArbitrum() external {
        vm.createSelectFork(vm.envString("ARBITRUM_MAINNET_RPC_URL"), 80_000_000);

        TellorValueProvider arbitrum = new TellorValueProvider(TELLOR_ORACLE, address(1));
        arbitrum.setDenomination(Denominations.ETH, Denominations.ETH);
        arbitrum.setQueryId(Denominations.ETH, QUERY_ID);

        vm.prank(address(1));

        uint256 returnedPrice = arbitrum.getPrice(Denominations.ETH);

        assertGt(returnedPrice, 0);
        assertLt(returnedPrice, ETH_MAX_USD);
    }
}
