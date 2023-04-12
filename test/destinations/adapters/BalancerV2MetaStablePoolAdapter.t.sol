// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdStorage.sol";

import "../../../src/destinations/adapters/BalancerV2MetaStablePoolAdapter.sol";
import "../../../src/interfaces/destinations/IDestinationRegistry.sol";
import "../../../src/interfaces/destinations/IDestinationAdapter.sol";
import "../../../src/interfaces/external/balancer/IVault.sol";
import {
    PRANK_ADDRESS,
    RANDOM,
    WETH_MAINNET,
    RETH_MAINNET,
    WSTETH_MAINNET,
    SFRXETH_MAINNET,
    CBETH_MAINNET,
    WSTETH_ARBITRUM,
    WETH_ARBITRUM,
    WSTETH_OPTIMISM,
    WETH9_OPTIMISM,
    RETH_OPTIMISM
} from "../../utils/Addresses.sol";

contract BalancerV2MetaStablePoolAdapterTest is Test {
    using stdStorage for StdStorage;

    uint256 public mainnetFork;
    BalancerV2MetaStablePoolAdapter public adapter;

    struct BalancerExtraParams {
        bytes32 poolId;
        IERC20[] tokens;
    }

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
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        adapter = new BalancerV2MetaStablePoolAdapter(IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8));
    }

    function forkArbitrum() private {
        string memory endpoint = vm.envString("ARBITRUM_MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint);
        vm.selectFork(forkId);
        assertEq(vm.activeFork(), forkId);
        adapter = new BalancerV2MetaStablePoolAdapter(IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8));
    }

    function forkOptimism() private {
        string memory endpoint = vm.envString("OPTIMISM_MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint);
        vm.selectFork(forkId);
        assertEq(vm.activeFork(), forkId);
        adapter = new BalancerV2MetaStablePoolAdapter(IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8));
    }

    function testAddLiquidityWstEthCbEth() public {
        bytes32 poolId = 0x9c6d47ff73e0f5e51be5fd53236e3f595c5793f200020000000000000000042c;
        address poolAddress = 0x9c6d47Ff73e0F5E51BE5FD53236e3F595C5793F2;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        deal(address(WSTETH_MAINNET), address(adapter), 2 * 1e18);
        deal(address(CBETH_MAINNET), address(adapter), 2 * 1e18);

        uint256 preBalance1 = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(CBETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_MAINNET);
        tokens[1] = IERC20(CBETH_MAINNET);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(CBETH_MAINNET).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance1, preBalance1 - amounts[0]);
        assertEq(afterBalance2, preBalance2 - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testRemoveLiquidityWstEthCbEth() public {
        bytes32 poolId = 0x9c6d47ff73e0f5e51be5fd53236e3f595c5793f200020000000000000000042c;
        address poolAddress = 0x9c6d47Ff73e0F5E51BE5FD53236e3F595C5793F2;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1.5 * 1e18;
        amounts[1] = 1.5 * 1e18;

        deal(address(WSTETH_MAINNET), address(adapter), 2 * 1e18);
        deal(address(CBETH_MAINNET), address(adapter), 2 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_MAINNET);
        tokens[1] = IERC20(CBETH_MAINNET);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(CBETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 1 * 1e18;
        withdrawAmounts[1] = 1 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(CBETH_MAINNET).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }

    function testAddLiquidityWstEthWeth() public {
        bytes32 poolId = 0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080;
        address poolAddress = 0x32296969Ef14EB0c6d29669C550D4a0449130230;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        deal(address(WSTETH_MAINNET), address(adapter), 2 * 1e18);

        deal(address(WETH_MAINNET), address(adapter), 2 * 1e18);

        uint256 preBalance1 = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_MAINNET);
        tokens[1] = IERC20(WETH_MAINNET);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance1, preBalance1 - amounts[0]);
        assertEq(afterBalance2, preBalance2 - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testRemoveLiquidityWstEthWeth() public {
        bytes32 poolId = 0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080;
        address poolAddress = 0x32296969Ef14EB0c6d29669C550D4a0449130230;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1.5 * 1e18;
        amounts[1] = 1.5 * 1e18;

        deal(address(WSTETH_MAINNET), address(adapter), 2 * 1e18);
        deal(address(WETH_MAINNET), address(adapter), 2 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_MAINNET);
        tokens[1] = IERC20(WETH_MAINNET);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 1 * 1e18;
        withdrawAmounts[1] = 1 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }

    function testAddLiquidityRethWeth() public {
        bytes32 poolId = 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112;
        address poolAddress = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        deal(address(RETH_MAINNET), address(adapter), 2 * 1e18);
        deal(address(WETH_MAINNET), address(adapter), 2 * 1e18);

        uint256 preBalance1 = IERC20(RETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(RETH_MAINNET);
        tokens[1] = IERC20(WETH_MAINNET);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(RETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance1, preBalance1 - amounts[0]);
        assertEq(afterBalance2, preBalance2 - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testRemoveLiquidityRethWeth() public {
        bytes32 poolId = 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112;
        address poolAddress = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1.5 * 1e18;
        amounts[1] = 1.5 * 1e18;

        deal(address(RETH_MAINNET), address(adapter), 2 * 1e18);
        deal(address(WETH_MAINNET), address(adapter), 2 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(RETH_MAINNET);
        tokens[1] = IERC20(WETH_MAINNET);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(RETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 1 * 1e18;
        withdrawAmounts[1] = 1 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(RETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }

    function testAddLiquidityWstEthWethArbitrum() public {
        forkArbitrum();

        bytes32 poolId = 0x36bf227d6bac96e2ab1ebb5492ecec69c691943f000200000000000000000316;
        address poolAddress = 0x36bf227d6BaC96e2aB1EbB5492ECec69C691943f;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        deal(address(WSTETH_ARBITRUM), address(adapter), 2 * 1e18);

        deal(address(WETH_ARBITRUM), address(adapter), 2 * 1e18);

        uint256 preBalance1 = IERC20(WSTETH_ARBITRUM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH_ARBITRUM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_ARBITRUM);
        tokens[1] = IERC20(WETH_ARBITRUM);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_ARBITRUM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH_ARBITRUM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance1, preBalance1 - amounts[0]);
        assertEq(afterBalance2, preBalance2 - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testRemoveLiquidityWstEthWethArbitrum() public {
        forkArbitrum();

        bytes32 poolId = 0x36bf227d6bac96e2ab1ebb5492ecec69c691943f000200000000000000000316;
        address poolAddress = 0x36bf227d6BaC96e2aB1EbB5492ECec69C691943f;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1.5 * 1e18;
        amounts[1] = 1.5 * 1e18;

        deal(address(WSTETH_ARBITRUM), address(adapter), 2 * 1e18);
        deal(address(WETH_ARBITRUM), address(adapter), 2 * 1e18);

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(WSTETH_ARBITRUM);
        tokens[1] = IERC20(WETH_ARBITRUM);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 preBalance1 = IERC20(WSTETH_ARBITRUM).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(WETH_ARBITRUM).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256[] memory withdrawAmounts = new uint256[](2);
        withdrawAmounts[0] = 1 * 1e18;
        withdrawAmounts[1] = 1 * 1e18;
        adapter.removeLiquidity(withdrawAmounts, preLpBalance, extraParams);

        uint256 afterBalance1 = IERC20(WSTETH_ARBITRUM).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(WETH_ARBITRUM).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assert(afterBalance1 > preBalance1);
        assert(afterBalance2 > preBalance2);
        assert(aftrerLpBalance < preLpBalance);
    }

    // Bethoven X
    function testAddLiquidityWstEthWethOptimism() public {
        forkOptimism();

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

    function testRemoveLiquidityWstEthWethOptimism() public {
        forkOptimism();

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

    function testAddLiquidityRethWethOptimism() public {
        forkOptimism();

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

    function testRemoveLiquidityRethWethOptimism() public {
        forkOptimism();

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
