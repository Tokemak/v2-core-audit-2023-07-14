// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IVault } from "src/interfaces/external/balancer/IVault.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import { ISyncSwapper } from "src/interfaces/swapper/ISyncSwapper.sol";
import { CurveV2Swap } from "src/swapper/adapters/CurveStableSwap.sol";
import { IDestinationVaultRegistry, DestinationVaultRegistry } from "src/vault/DestinationVaultRegistry.sol";
import { ICurveStableSwap } from "src/interfaces/external/curve/ICurveStableSwap.sol";

import { WSTETH_MAINNET, STETH_MAINNET, WETH_MAINNET, RANDOM } from "test/utils/Addresses.sol";

// solhint-disable func-name-mixedcase
contract CurveStableSwapTest is Test {
    CurveV2Swap private adapter;

    ISwapRouter.SwapData private route;

    function setUp() public {
        string memory endpoint = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_728_070);
        vm.selectFork(forkId);

        adapter = new CurveV2Swap(address(1));

        // route WETH_MAINNET -> STETH_MAINNET
        route = ISwapRouter.SwapData({
            token: STETH_MAINNET,
            pool: 0x828b154032950C8ff7CF8085D841723Db2696056,
            swapper: adapter,
            data: abi.encode(0, 1)
        });
    }

    function test_validate_Revert_IfFromAddressMismatch() public {
        // pretend that the pool doesn't have WETH_MAINNET
        vm.mockCall(route.pool, abi.encodeWithSelector(ICurveStableSwap.coins.selector, 0), abi.encode(RANDOM));
        vm.expectRevert(abi.encodeWithSelector(ISyncSwapper.DataMismatch.selector, "fromAddress"));
        adapter.validate(WETH_MAINNET, route);
    }

    function test_validate_Revert_IfToAddressMismatch() public {
        // pretend that the pool doesn't have STETH_MAINNET
        vm.mockCall(route.pool, abi.encodeWithSelector(ICurveStableSwap.coins.selector, 1), abi.encode(RANDOM));
        vm.expectRevert(abi.encodeWithSelector(ISyncSwapper.DataMismatch.selector, "toAddress"));
        adapter.validate(WETH_MAINNET, route);
    }

    function test_validate_Works() public view {
        adapter.validate(WETH_MAINNET, route);
    }
}
