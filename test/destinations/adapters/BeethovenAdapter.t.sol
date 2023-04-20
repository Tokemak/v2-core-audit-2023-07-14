// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdStorage.sol";

import "../../../src/destinations/adapters/BeethovenAdapter.sol";
import "../../../src/interfaces/destinations/IDestinationRegistry.sol";
import "../../../src/interfaces/destinations/IDestinationAdapter.sol";
import "../../../src/interfaces/external/balancer/IVault.sol";
import { WSTETH_OPTIMISM, WETH9_OPTIMISM, RETH_OPTIMISM } from "../../utils/Addresses.sol";

contract BeethovenAdapterTest is Test {
    BeethovenAdapter private adapter;

    struct BalancerExtraParams {
        bytes32 poolId;
        IERC20[] tokens;
    }

    function setUp() public {
        string memory endpoint = vm.envString("OPTIMISM_MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint);
        vm.selectFork(forkId);
        assertEq(vm.activeFork(), forkId);
        adapter = new BeethovenAdapter(IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8));
    }

    function testAddLiquidityWstEthWeth() public {
        bytes32 poolId = 0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb200020000000000000000008b;
        address poolAddress = 0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        deal(address(WSTETH_OPTIMISM), address(adapter), 2 * 1e18);
        deal(address(WETH9_OPTIMISM), address(adapter), 2 * 1e18);

        uint256 preBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_OPTIMISM);
        tokens[1] = IERC20(WETH9_OPTIMISM);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance1, preBalance1 - amounts[0]);
        assertEq(afterBalance2, preBalance2 - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testRemoveLiquidityWstEthWeth() public {
        bytes32 poolId = 0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb200020000000000000000008b;
        address poolAddress = 0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1.5 * 1e18;
        amounts[1] = 1.5 * 1e18;

        deal(address(WSTETH_OPTIMISM), address(adapter), 2 * 1e18);
        deal(address(WETH9_OPTIMISM), address(adapter), 2 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_OPTIMISM);
        tokens[1] = IERC20(WETH9_OPTIMISM);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 1 * 1e18;
        withdrawAmounts[1] = 1 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }

    function testAddLiquidityRethWeth() public {
        bytes32 poolId = 0x4fd63966879300cafafbb35d157dc5229278ed2300020000000000000000002b;
        address poolAddress = 0x4Fd63966879300caFafBB35D157dC5229278Ed23;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        deal(address(RETH_OPTIMISM), address(adapter), 2 * 1e18);
        deal(address(WETH9_OPTIMISM), address(adapter), 2 * 1e18);

        uint256 preBalance1 = IERC20(RETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WETH9_OPTIMISM);
        tokens[1] = IERC20(RETH_OPTIMISM);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(RETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance1, preBalance1 - amounts[0]);
        assertEq(afterBalance2, preBalance2 - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testRemoveLiquidityRethWeth() public {
        bytes32 poolId = 0x4fd63966879300cafafbb35d157dc5229278ed2300020000000000000000002b;
        address poolAddress = 0x4Fd63966879300caFafBB35D157dC5229278Ed23;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1.5 * 1e18;
        amounts[1] = 1.5 * 1e18;

        deal(address(RETH_OPTIMISM), address(adapter), 2 * 1e18);
        deal(address(WETH9_OPTIMISM), address(adapter), 2 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WETH9_OPTIMISM);
        tokens[1] = IERC20(RETH_OPTIMISM);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(RETH_OPTIMISM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 1 * 1e18;
        withdrawAmounts[1] = 1 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(RETH_OPTIMISM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH9_OPTIMISM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }
}
