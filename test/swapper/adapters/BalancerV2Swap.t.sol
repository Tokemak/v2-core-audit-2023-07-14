// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IVault } from "src/interfaces/external/balancer/IVault.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import { ISyncSwapper } from "src/interfaces/swapper/ISyncSwapper.sol";
import { BalancerV2Swap } from "src/swapper/adapters/BalancerV2Swap.sol";
import { IDestinationVaultRegistry, DestinationVaultRegistry } from "src/vault/DestinationVaultRegistry.sol";

import {
    WSTETH_MAINNET, RETH_MAINNET, STETH_MAINNET, WETH_MAINNET, FRXETH_MAINNET, RANDOM
} from "test/utils/Addresses.sol";

// solhint-disable func-name-mixedcase
contract BalancerV2SwapTest is Test {
    address private constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    BalancerV2Swap private adapter;

    ISwapRouter.SwapData private route;

    function setUp() public {
        string memory endpoint = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_728_070);
        vm.selectFork(forkId);

        adapter = new BalancerV2Swap(address(1), BALANCER_VAULT);

        // route WETH_MAINNET -> WSTETH_MAINNET
        route = ISwapRouter.SwapData({
            token: WSTETH_MAINNET,
            pool: 0x32296969Ef14EB0c6d29669C550D4a0449130230,
            swapper: adapter,
            data: abi.encode(0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080)
        });
    }

    function test_validate_Revert_IfFromAddressMismatch() public {
        bytes32 poolId = abi.decode(route.data, (bytes32));

        // pretend that the pool doesn't have WETH_MAINNET
        vm.mockCallRevert(
            BALANCER_VAULT,
            abi.encodeWithSelector(IVault.getPoolTokenInfo.selector, poolId, WETH_MAINNET),
            abi.encode("REVERT_MESSAGE")
        );
        vm.expectRevert(abi.encodeWithSelector(ISyncSwapper.DataMismatch.selector, "fromAddress"));
        adapter.validate(WETH_MAINNET, route);
    }

    function test_validate_Revert_IfToAddressMismatch() public {
        bytes32 poolId = abi.decode(route.data, (bytes32));

        // pretend that the pool doesn't have WSTETH_MAINNET
        vm.mockCallRevert(
            BALANCER_VAULT,
            abi.encodeWithSelector(IVault.getPoolTokenInfo.selector, poolId, WSTETH_MAINNET),
            abi.encode("REVERT_MESSAGE")
        );
        vm.expectRevert(abi.encodeWithSelector(ISyncSwapper.DataMismatch.selector, "toAddress"));
        adapter.validate(WETH_MAINNET, route);
    }

    function test_validate_Works() public view {
        adapter.validate(WETH_MAINNET, route);
    }
}
