// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { SwapData, LPTokenSwapper } from "../../src/vault/LPTokenSwapper.sol";
import { BalancerV2Swap } from "../../src/vault/BalancerV2Swap.sol";
import { CurveV2Swap } from "../../src/vault/CurveV2Swap.sol";
import "../../src/interfaces/swapper/ISyncSwapper.sol";
import {
    WSTETH_MAINNET, RETH_MAINNET, STETH_MAINNET, WETH_MAINNET, FRXETH_MAINNET, RANDOM
} from "../utils/addresses.sol";
import { console2 as console } from "forge-std/console2.sol";

// solhint-disable func-name-mixedcase
contract LPTokenSwapperTest is Test {
    using stdStorage for StdStorage;

    LPTokenSwapper private testswapper;
    BalancerV2Swap private balSwapper;
    CurveV2Swap private curveSwapper;

    error ApprovalFailed();
    error RouterTransferFailed();

    function setUp() public {
        string memory endpoint = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 16_728_070);
        vm.selectFork(forkId);

        testswapper = new LPTokenSwapper();

        SwapData[] memory swapD;        
        // setup input for Balancer swap
        // swapper for WSTETH_MAINNET
        address vAdd = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
        balSwapper = new BalancerV2Swap(vAdd);
        swapD[0].swapper = balSwapper;
        swapD[0].token = WSTETH_MAINNET;
        swapD[0].pool = 0x32296969Ef14EB0c6d29669C550D4a0449130230;

        testswapper.setSwapLookUpEntry(WETH_MAINNET, swapD[0].token, swapD);

        // setup input for Curve 1-hop
        curveSwapper = new CurveV2Swap();
        swapD[0].swapper = curveSwapper;
        swapD[0].token = STETH_MAINNET;
        swapD[0].pool = 0x828b154032950C8ff7CF8085D841723Db2696056;
        testswapper.setSwapLookUpEntry(WETH_MAINNET, swapD[0].token, swapD);

        // setup input for Curve 2-hop
        swapD[1].swapper = curveSwapper;
        swapD[1].token = FRXETH_MAINNET;
        swapD[1].pool = 0x4d9f9D15101EEC665F77210cB999639f760F831E;

        testswapper.setSwapLookUpEntry(WETH_MAINNET, swapD[1].token, swapD);
    }

    // This function does the actual swap transactions
    function test_swap_router() public {
        // console.log(address(testswapper));
        uint256 sellAmount = 1e18;
        // swap STETH with Curve pool
        address asset1 = WETH_MAINNET;
        address quoteT1 = STETH_MAINNET;
        uint256 val1;
        deal(WETH_MAINNET, address(this), 10 * 1e18);
        if (!IERC20(WETH_MAINNET).approve(address(testswapper), 10 * 1e18)) {
            revert ApprovalFailed();
        }

        // sellAmount = 0 should return 0
        val1 = testswapper.swapForQuote(asset1, 0, quoteT1, 0);
        assert(val1 == 0);

        // revert test - min buy amount > sell amount for 1:1 tokens
        vm.expectRevert(LPTokenSwapper.SwapFailedDuetoInsufficientBuy.selector);
        val1 = testswapper.swapForQuote(asset1, sellAmount, quoteT1, 2 * sellAmount);

        // revert test - incorrect entry in mapping
        ISyncSwapper[] memory swappers;
        swappers = new ISyncSwapper[](1);
        address[] memory tPath;
        tPath = new address[](1);
        address[] memory pPath;
        pPath = new address[](2);

        // revert test - incorrect sell token
        vm.expectRevert(LPTokenSwapper.SwapMappingLookupFailed.selector);
        val1 = testswapper.swapForQuote(RANDOM, sellAmount, quoteT1, 0);

        // revert test - incorrect quote token
        vm.expectRevert(LPTokenSwapper.SwapMappingLookupFailed.selector);
        val1 = testswapper.swapForQuote(asset1, sellAmount, RANDOM, 0);
    }

    function test_swap_Curve() public {
        // console.log(address(testswapper));
        uint256 sellAmount = 2;
        // swap STETH with Curve pool
        address asset1 = WETH_MAINNET;
        address quoteT1 = STETH_MAINNET;
        uint256 val1;
        deal(WETH_MAINNET, address(this), 10 * 1e18);
        if (!IERC20(WETH_MAINNET).approve(address(testswapper), 4 * 1e18)) {
            revert ApprovalFailed();
        }
        // 1-hop swap: WETH -> STETH
        val1 = testswapper.swapForQuote(asset1, sellAmount, quoteT1, 0);
        // Verify txn
        assert(val1 > 0);

        // 2-hop swap: WETH -> STETH -> FRXETH
        quoteT1 = FRXETH_MAINNET;
        val1 = testswapper.swapForQuote(asset1, sellAmount, quoteT1, 0);
        assert(val1 > 0);
    }

    function test_swap_Balancer() public {
        // console.log(address(testswapper));
        uint256 sellAmount = 1e18;
        // swap WSTETH with Balancer pool
        address asset2 = WETH_MAINNET;
        address quoteT2 = WSTETH_MAINNET;

        uint256 val2;
        deal(WETH_MAINNET, address(this), 10 * 1e18);
        if (!IERC20(WETH_MAINNET).approve(address(testswapper), 2 * 1e18)) {
            revert ApprovalFailed();
        }
        val2 = testswapper.swapForQuote(asset2, sellAmount, quoteT2, 0);
        // Verify txn
    }
}
