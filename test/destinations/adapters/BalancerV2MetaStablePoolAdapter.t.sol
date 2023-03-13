// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdStorage.sol";

import "../../../src/destinations/adapters/BalancerV2MetaStablePoolAdapter.sol";
import "../../../src/interfaces/destinations/IDestinationRegistry.sol";
import "../../../src/interfaces/destinations/IDestinationAdapter.sol";
import "../../../src/interfaces/external/balancer/IVault.sol";
import { PRANK_ADDRESS, RANDOM } from "../../utils/Addresses.sol";

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
        mainnetFork = vm.createFork(vm.envString("TEST_ALCHEMY_MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        adapter = new BalancerV2MetaStablePoolAdapter(IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8));
    }

    // Add liquidity
    function testAddLiquidityWstEthWeth() public {
        bytes32 poolId = 0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080;
        address poolAddress = 0x32296969Ef14EB0c6d29669C550D4a0449130230;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        deal(address(wsteth), address(adapter), 2 * 1e18);
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        deal(address(weth), address(adapter), 2 * 1e18);

        uint256 preBalance1 = IERC20(wsteth).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(weth).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(wsteth);
        tokens[1] = IERC20(weth);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(wsteth).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(weth).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance1, preBalance1 - amounts[0]);
        assertEq(afterBalance2, preBalance2 - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testAddLiquidityRethWeth() public {
        bytes32 poolId = 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112;
        address poolAddress = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        address reth = 0xae78736Cd615f374D3085123A210448E74Fc6393;
        deal(address(reth), address(adapter), 2 * 1e18);
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        deal(address(weth), address(adapter), 2 * 1e18);

        uint256 preBalance1 = IERC20(reth).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(weth).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(reth);
        tokens[1] = IERC20(weth);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(reth).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(weth).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance1, preBalance1 - amounts[0]);
        assertEq(afterBalance2, preBalance2 - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }

    function testAddLiquidityWstEthCbEth() public {
        bytes32 poolId = 0x9c6d47ff73e0f5e51be5fd53236e3f595c5793f200020000000000000000042c;
        address poolAddress = 0x9c6d47Ff73e0F5E51BE5FD53236e3F595C5793F2;
        IERC20 lpToken = IERC20(poolAddress);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.5 * 1e18;
        amounts[1] = 0.5 * 1e18;

        address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        deal(address(wsteth), address(adapter), 2 * 1e18);
        address cbeth = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
        deal(address(cbeth), address(adapter), 2 * 1e18);

        uint256 preBalance1 = IERC20(wsteth).balanceOf(address(adapter));
        uint256 preBalance2 = IERC20(cbeth).balanceOf(address(adapter));
        uint256 preLpBalance = lpToken.balanceOf(address(adapter));

        uint256 minLpMintAmount = 1;

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(wsteth);
        tokens[1] = IERC20(cbeth);

        bytes memory extraParams = abi.encode(BalancerExtraParams(poolId, tokens));
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalance1 = IERC20(wsteth).balanceOf(address(adapter));
        uint256 afterBalance2 = IERC20(cbeth).balanceOf(address(adapter));
        uint256 aftrerLpBalance = lpToken.balanceOf(address(adapter));

        assertEq(afterBalance1, preBalance1 - amounts[0]);
        assertEq(afterBalance2, preBalance2 - amounts[1]);
        assert(aftrerLpBalance > preLpBalance);
    }
}
