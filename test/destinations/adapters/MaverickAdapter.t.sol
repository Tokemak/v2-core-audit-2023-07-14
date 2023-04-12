// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdStorage.sol";

import "../../../src/destinations/adapters/MaverickAdapter.sol";
import "../../../src/interfaces/destinations/IDestinationRegistry.sol";
import "../../../src/interfaces/destinations/IDestinationAdapter.sol";
import { IPool } from "../../../src/interfaces/external/maverick/IPool.sol";
import { IRouter } from "../../../src/interfaces/external/maverick/IRouter.sol";
import {
    PRANK_ADDRESS,
    RANDOM,
    WSTETH_MAINNET,
    RETH_MAINNET,
    SETH_MAINNET,
    FRXETH_MAINNET,
    STETH_MAINNET,
    WETH_MAINNET
} from "../../utils/Addresses.sol";

import { console2 } from "forge-std/console2.sol";

contract MaverickAdapterTest is Test {
    uint256 public mainnetFork;
    MaverickAdapter public adapter;

    struct MaverickExtraParams {
        address poolAddress;
        uint256 tokenId;
        uint256 deadline;
        IPool.AddLiquidityParams[] maverickParams;
        uint256 minAmountA;
        uint256 minAmountB;
    }

    /// @notice Parameters for each bin that will get new liquidity
    /// @param kind one of the 4 Kinds (0=static, 1=right, 2=left, 3=both)
    /// @param pos bin position
    /// @param isDelta bool that indicates whether the bin position is relative
    //to the current bin or an absolute position
    /// @param deltaA amount of A token to add
    /// @param deltaB amount of B token to add
    struct AddLiquidityParams {
        uint8 kind;
        int32 pos;
        bool isDelta;
        uint128 deltaA;
        uint128 deltaB;
    }

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        adapter = new MaverickAdapter(IRouter(0xc3B7aF1d8c3ca78F375Eb125F0211164b9071Cc0));
    }

    function testAddLiquidityEthWstEth() public {
        IPool pool = IPool(0x2eBE19AA2e29C8ACaDb14Be3E7De153b0141e2aa);

        uint256[] memory amounts = new uint256[](2);
        uint128 deltaA = 5 * 1e18;
        uint128 deltaB = 5 * 1e18;
        amounts[0] = deltaA;
        amounts[1] = deltaB;

        deal(address(WETH_MAINNET), address(adapter), 10 * 1e18);
        deal(address(WSTETH_MAINNET), address(adapter), 10 * 1e18);
        // vm.deal(address(adapter), 3 ether);

        uint256 tokenId = 1;
        uint32 binPos = 0;
        uint256 preBalanceA = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalanceB = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = pool.balanceOf(tokenId, 9);

        /// @notice Parameters for each bin that will get new liquidity
        /// @param kind one of the 4 Kinds (0=static, 1=right, 2=left, 3=both)
        /// @param pos bin position
        /// @param isDelta bool that indicates whether the bin position is relative
        /// to the current bin or an absolute position
        /// @param deltaA amount of A token to add
        /// @param deltaB amount of B token to add
        // struct IPool.AddLiquidityParams {
        //     uint8 kind;
        //     int32 pos;
        //     bool isDelta;
        //     uint128 deltaA;
        //     uint128 deltaB;
        // }
        IPool.AddLiquidityParams[] memory maverickParams = new  IPool.AddLiquidityParams[](1);
        maverickParams[0] = IPool.AddLiquidityParams(3, int32(binPos), true, deltaA, deltaB);

        bytes memory extraParams = abi.encode(
            MaverickExtraParams(
                address(pool),
                tokenId,
                1e13,
                maverickParams,
                // amounts[0] - (amounts[0] / 2),
                // amounts[1] - (amounts[1] / 2)
                1 * 1e18,
                1 * 1e18
            )
        );
        uint256 minLpMintAmount = 1;
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalanceA = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalanceB = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 aftrerLpBalance = pool.balanceOf(tokenId, 9);

        assertTrue(afterBalanceA < preBalanceA);
        assertTrue(afterBalanceB < preBalanceB);

        // assertEq(afterBalance, preBalance - amounts[0]);
        assert(aftrerLpBalance > preLpBalance);
    }
}
