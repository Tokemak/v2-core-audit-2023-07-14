// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdStorage.sol";

import "../../../src/destinations/adapters/CurveV2FactoryCryptoAdapter.sol";
import "../../../src/interfaces/destinations/IDestinationRegistry.sol";
import "../../../src/interfaces/destinations/IDestinationAdapter.sol";
import { ICryptoSwapPool, IPool } from "../../../src/interfaces/external/curve/ICryptoSwapPool.sol";
import { PRANK_ADDRESS, RANDOM } from "../../utils/Addresses.sol";

contract CurveV2FactoryCryptoAdapterTest is Test {
    using stdStorage for StdStorage;

    uint256 public mainnetFork;
    CurveV2FactoryCryptoAdapter public adapter;

    event DeployLiquidity(
        uint256[] amountsDeposited,
        address[] tokens,
        uint256 lpMintAmount,
        uint256 lpShare,
        uint256 lpTotalSupply,
        bytes extraData
    );

    event WithdrawLiquidity(
        uint256[] amountsWithdrawn,
        address[] tokens,
        uint256 lpBurnAmount,
        uint256 lpShare,
        uint256 lpTotalSupply,
        bytes extraData
    );

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("TEST_ALCHEMY_MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        adapter = new CurveV2FactoryCryptoAdapter();
    }

    // Add liquidity
    function testAddLiquidityWethStEth() public {
        address poolAddress = 0x5FAE7E604FC3e24fd43A72867ceBaC94c65b404A;
        ICryptoSwapPool pool = ICryptoSwapPool(poolAddress);
        IERC20 lpToken = IERC20(pool.token());

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0;

        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        deal(address(weth), address(adapter), 2 * 1e18);

        uint256 preBalance = IERC20(weth).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        bytes memory extraParams = abi.encode(poolAddress, address(lpToken), false);
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance = IERC20(weth).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance, preBalance - amounts[0]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testAddLiquidityRethWstEth() public {
        address poolAddress = 0x447Ddd4960d9fdBF6af9a790560d0AF76795CB08;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0;

        address reth = 0xae78736Cd615f374D3085123A210448E74Fc6393;
        deal(address(reth), address(adapter), 2 * 1e18);

        uint256 preBalance = IERC20(reth).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        bytes memory extraParams = abi.encode(poolAddress, address(lpToken), false);
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance = IERC20(reth).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance, preBalance - amounts[0]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testAddLiquidityEthSeth() public {
        address poolAddress = 0xc5424B857f758E906013F3555Dad202e4bdB4567;
        IERC20 lpToken = IERC20(0xA3D87FffcE63B53E0d54fAa1cc983B7eB0b74A9c);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        vm.deal(address(adapter), 3 ether);
        address seth = 0x5e74C9036fb86BD7eCdcb084a0673EFc32eA31cb;

        // Using whale for funding since storage slot overwrite is not working for proxy ERC-20s
        address sethWhale = 0x5fe009D78AfABc1b04AbD2D4361f8E95cD402648;
        vm.prank(sethWhale);
        IERC20(seth).approve(address(adapter), 2 * 1e18);
        vm.prank(sethWhale);
        IERC20(seth).transfer(address(adapter), 2 * 1e18);

        uint256 preEthBalance = address(adapter).balance;
        uint256 preBalance = IERC20(seth).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        bytes memory extraParams = abi.encode(poolAddress, address(lpToken), true);
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterEthBalance = address(adapter).balance;
        uint256 afterBalance = IERC20(seth).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterEthBalance, preEthBalance - amounts[0]);
        assertEq(afterBalance, preBalance - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testAddLiquidityEthFrxEth() public {
        address poolAddress = 0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577;
        IERC20 lpToken = IERC20(0xf43211935C781D5ca1a41d2041F397B8A7366C7A);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        vm.deal(address(adapter), 2 ether);
        address frxeth = 0x5E8422345238F34275888049021821E8E08CAa1f;
        deal(address(frxeth), address(adapter), 2 * 1e18);

        uint256 preEthBalance = address(adapter).balance;
        uint256 preBalance = IERC20(frxeth).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        bytes memory extraParams = abi.encode(poolAddress, address(lpToken), true);
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterEthBalance = address(adapter).balance;
        uint256 afterBalance = IERC20(frxeth).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterEthBalance, preEthBalance - amounts[0]);
        assertEq(afterBalance, preBalance - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }
}
