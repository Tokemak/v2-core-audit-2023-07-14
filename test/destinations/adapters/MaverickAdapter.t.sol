// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/StdStorage.sol";

import "../../../src/destinations/adapters/MaverickAdapter.sol";
import "../../../src/interfaces/destinations/IDestinationRegistry.sol";
import "../../../src/interfaces/destinations/IDestinationAdapter.sol";
import "../../../src/interfaces/external/maverick/IPool.sol";
import "../../../src/interfaces/external/maverick/IRouter.sol";
import { WSTETH_MAINNET, CBETH_MAINNET, STETH_MAINNET, WETH_MAINNET } from "../../utils/Addresses.sol";

contract MaverickAdapterTest is Test {
    struct MaverickDeploymentExtraParams {
        address poolAddress;
        uint256 tokenId;
        uint256 deadline;
        IPool.AddLiquidityParams[] maverickParams;
    }

    struct MaverickWithdrawalExtraParams {
        address poolAddress;
        uint256 tokenId;
        uint256 deadline;
        IPool.RemoveLiquidityParams[] maverickParams;
    }

    // solhint-disable-next-line var-name-mixedcase
    uint256 private INITIAL_TOKEN_ID = 0;

    uint256 private mainnetFork;
    IRouter private router;
    IPosition private position;
    MaverickAdapter private adapter;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 17_067_052);
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        router = IRouter(0xc3B7aF1d8c3ca78F375Eb125F0211164b9071Cc0);
        position = router.position();
        adapter = new MaverickAdapter(router);
    }

    // wstETH/WETH
    function testAddLiquidityWethWstEth() public {
        IPool pool = IPool(0x2eBE19AA2e29C8ACaDb14Be3E7De153b0141e2aa);

        uint256[] memory amounts = new uint256[](2);
        uint128 deltaA = 5 * 1e18;
        uint128 deltaB = 5 * 1e18;
        amounts[0] = 1 * 1e18;
        amounts[1] = 1 * 1e18;

        deal(address(WETH_MAINNET), address(adapter), 10 * 1e18);
        deal(address(WSTETH_MAINNET), address(adapter), 10 * 1e18);

        uint128 binId = 49;

        uint256 preBalanceA = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalanceB = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = pool.balanceOf(INITIAL_TOKEN_ID, binId);

        IPool.AddLiquidityParams[] memory maverickParams = new  IPool.AddLiquidityParams[](1);
        maverickParams[0] = IPool.AddLiquidityParams(3, 0, true, deltaA, deltaB);

        bytes memory extraParams =
            abi.encode(MaverickDeploymentExtraParams(address(pool), INITIAL_TOKEN_ID, 1e13, maverickParams));

        uint256 minLpMintAmount = 1;
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalanceA = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalanceB = IERC20(WETH_MAINNET).balanceOf(address(adapter));

        uint256 tokenId = position.tokenOfOwnerByIndex(address(adapter), 0);
        uint256 aftrerLpBalance = pool.balanceOf(tokenId, binId);

        assertTrue(afterBalanceA < preBalanceA);
        assertTrue(afterBalanceB < preBalanceB);
        assert(aftrerLpBalance > preLpBalance);
    }

    // wstETH/WETH
    function testRemoveLiquidityWethWstEth() public {
        IPool pool = IPool(0x2eBE19AA2e29C8ACaDb14Be3E7De153b0141e2aa);

        uint256[] memory amounts = new uint256[](2);
        uint128 deltaA = 5 * 1e18;
        uint128 deltaB = 5 * 1e18;
        amounts[0] = 1 * 1e18;
        amounts[1] = 1 * 1e18;

        deal(address(WETH_MAINNET), address(adapter), 10 * 1e18);
        deal(address(WSTETH_MAINNET), address(adapter), 10 * 1e18);

        IPool.AddLiquidityParams[] memory maverickParams = new  IPool.AddLiquidityParams[](1);
        maverickParams[0] = IPool.AddLiquidityParams(3, 0, true, deltaA, deltaB);

        bytes memory extraParams =
            abi.encode(MaverickDeploymentExtraParams(address(pool), INITIAL_TOKEN_ID, 1e13, maverickParams));

        adapter.addLiquidity(amounts, 1, extraParams);

        uint128 binId = 49;
        uint256 withDrawTokenId = position.tokenOfOwnerByIndex(address(adapter), 0);

        uint256 preBalanceA = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalanceB = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = pool.balanceOf(withDrawTokenId, binId);

        IPool.RemoveLiquidityParams[] memory maverickWithdrawalParams = new  IPool.RemoveLiquidityParams[](1);
        maverickWithdrawalParams[0] = IPool.RemoveLiquidityParams(binId, uint128(preLpBalance));

        bytes memory extraWithdrawalParams =
            abi.encode(MaverickWithdrawalExtraParams(address(pool), withDrawTokenId, 1e13, maverickWithdrawalParams));

        adapter.removeLiquidity(amounts, preLpBalance, extraWithdrawalParams);

        uint256 afterBalanceA = IERC20(WSTETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalanceB = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 aftrerLpBalance = pool.balanceOf(withDrawTokenId, binId);

        assertTrue(afterBalanceA > preBalanceA);
        assertTrue(afterBalanceB > preBalanceB);
        assert(aftrerLpBalance < preLpBalance);
    }

    // cbETH/WETH
    function testAddLiquidityWethCbEth() public {
        IPool pool = IPool(0x5cB98367C32d8a1D910461c572C558d57cA68D25);

        uint256[] memory amounts = new uint256[](2);
        uint128 deltaA = 5 * 1e18;
        uint128 deltaB = 5 * 1e18;
        amounts[0] = 1 * 1e18;
        amounts[1] = 1 * 1e18;

        deal(address(WETH_MAINNET), address(adapter), 10 * 1e18);
        deal(address(CBETH_MAINNET), address(adapter), 10 * 1e18);

        uint128 binId = 34;

        uint256 preBalanceA = IERC20(CBETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalanceB = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = pool.balanceOf(INITIAL_TOKEN_ID, binId);

        IPool.AddLiquidityParams[] memory maverickParams = new  IPool.AddLiquidityParams[](1);
        maverickParams[0] = IPool.AddLiquidityParams(3, 0, true, deltaA, deltaB);

        bytes memory extraParams =
            abi.encode(MaverickDeploymentExtraParams(address(pool), INITIAL_TOKEN_ID, 1e13, maverickParams));

        uint256 minLpMintAmount = 1;
        adapter.addLiquidity(amounts, minLpMintAmount, extraParams);

        uint256 afterBalanceA = IERC20(CBETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalanceB = IERC20(WETH_MAINNET).balanceOf(address(adapter));

        uint256 tokenId = position.tokenOfOwnerByIndex(address(adapter), 0);
        uint256 aftrerLpBalance = pool.balanceOf(tokenId, binId);

        assertTrue(afterBalanceA < preBalanceA);
        assertTrue(afterBalanceB < preBalanceB);
        assert(aftrerLpBalance > preLpBalance);
    }

    // cbETH/WETH
    function testRemoveLiquidityWethCbEth() public {
        IPool pool = IPool(0x5cB98367C32d8a1D910461c572C558d57cA68D25);

        uint256[] memory amounts = new uint256[](2);
        uint128 deltaA = 5 * 1e18;
        uint128 deltaB = 5 * 1e18;
        amounts[0] = 1 * 1e18;
        amounts[1] = 1 * 1e18;

        deal(address(WETH_MAINNET), address(adapter), 10 * 1e18);
        deal(address(CBETH_MAINNET), address(adapter), 10 * 1e18);

        IPool.AddLiquidityParams[] memory maverickParams = new  IPool.AddLiquidityParams[](1);
        maverickParams[0] = IPool.AddLiquidityParams(3, 0, true, deltaA, deltaB);

        bytes memory extraParams =
            abi.encode(MaverickDeploymentExtraParams(address(pool), INITIAL_TOKEN_ID, 1e13, maverickParams));

        adapter.addLiquidity(amounts, 1, extraParams);

        uint128 binId = 34;
        uint256 withDrawTokenId = position.tokenOfOwnerByIndex(address(adapter), 0);

        uint256 preBalanceA = IERC20(CBETH_MAINNET).balanceOf(address(adapter));
        uint256 preBalanceB = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 preLpBalance = pool.balanceOf(withDrawTokenId, binId);

        IPool.RemoveLiquidityParams[] memory maverickWithdrawalParams = new  IPool.RemoveLiquidityParams[](1);
        maverickWithdrawalParams[0] = IPool.RemoveLiquidityParams(binId, uint128(preLpBalance));

        bytes memory extraWithdrawalParams =
            abi.encode(MaverickWithdrawalExtraParams(address(pool), withDrawTokenId, 1e13, maverickWithdrawalParams));

        adapter.removeLiquidity(amounts, preLpBalance, extraWithdrawalParams);

        uint256 afterBalanceA = IERC20(CBETH_MAINNET).balanceOf(address(adapter));
        uint256 afterBalanceB = IERC20(WETH_MAINNET).balanceOf(address(adapter));
        uint256 aftrerLpBalance = pool.balanceOf(withDrawTokenId, binId);

        assertTrue(afterBalanceA > preBalanceA);
        assertTrue(afterBalanceB > preBalanceB);
        assert(aftrerLpBalance < preLpBalance);
    }
}
