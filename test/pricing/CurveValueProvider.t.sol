// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {
    THREE_CURVE_POOL_MAINNET_LP,
    THREE_CURVE_MAINNET,
    DAI_MAINNET,
    USDT_MAINNET,
    USDC_MAINNET
} from "test/utils/Addresses.sol";

import "src/pricing/value-providers/CurveValueProvider.sol";

// solhint-disable func-name-mixedcase
contract CurveValueProviderTest is Test {
    CurveValueProvider public curveValueProvider;

    error ZeroAddress(string paramName);

    event CurvePoolRegistered(address lpToken, address pool);
    event CurvePoolRemoved(address lpToken, address pool);

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        // EthValueOracle.sol doesn't need to be deployed for these tests.
        curveValueProvider = new CurveValueProvider(address(1));
    }

    // Test `registerCurveLpToken()`
    function test_OnlyOwnerOnRegister() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(2));

        curveValueProvider.registerCurveLPToken(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET, 2);
    }

    function test_LpTokenZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector, "lpToken"));

        curveValueProvider.registerCurveLPToken(address(0), THREE_CURVE_MAINNET, 2);
    }

    function test_PoolZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector, "pool"));

        curveValueProvider.registerCurveLPToken(THREE_CURVE_POOL_MAINNET_LP, address(0), 2);
    }

    function test_PoolIdxMaxZero() external {
        vm.expectRevert(CurveValueProvider.MustBeGTZero.selector);

        curveValueProvider.registerCurveLPToken(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET, 0);
    }

    function test_RevertAlreadyRegistered() external {
        curveValueProvider.registerCurveLPToken(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET, 2);
        vm.expectRevert(CurveValueProvider.CurvePoolAlreadyRegistered.selector);

        curveValueProvider.registerCurveLPToken(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET, 2);
    }

    function test_PoolIdxOOB() external {
        vm.expectRevert(CurveValueProvider.MaxTokenIdxOutOfBounds.selector);

        curveValueProvider.registerCurveLPToken(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET, 5);
    }

    function test_ProperRegistration() external {
        vm.expectEmit(false, false, false, true);
        emit CurvePoolRegistered(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET);

        curveValueProvider.registerCurveLPToken(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET, 2);

        CurveValueProvider.CurvePool memory curvePool = curveValueProvider.getPoolInfo(THREE_CURVE_POOL_MAINNET_LP);

        assertEq(curvePool.pool, THREE_CURVE_MAINNET);
        assertEq(curvePool.poolIdxMax, 2);
        assertEq(curvePool.tokensInPool[0], DAI_MAINNET);
        assertEq(curvePool.tokensInPool[1], USDC_MAINNET);
        assertEq(curvePool.tokensInPool[2], USDT_MAINNET);
    }

    // Test `removeCurveLpToken()`
    function test_OnlyOwnerOnRemove() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(2));

        curveValueProvider.removeCurveLPToken(THREE_CURVE_POOL_MAINNET_LP);
    }

    function test_LpTokenZeroAddressRemove() external {
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector, "lpToken"));

        curveValueProvider.removeCurveLPToken(address(0));
    }

    function test_RevertPoolNotRegistered() external {
        vm.expectRevert(CurveValueProvider.CurvePoolNotRegistered.selector);

        curveValueProvider.removeCurveLPToken(THREE_CURVE_POOL_MAINNET_LP);
    }

    function test_ProperRemoval() external {
        curveValueProvider.registerCurveLPToken(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET, 2);

        vm.expectEmit(false, false, false, true);
        emit CurvePoolRemoved(THREE_CURVE_POOL_MAINNET_LP, THREE_CURVE_MAINNET);

        curveValueProvider.removeCurveLPToken(THREE_CURVE_POOL_MAINNET_LP);

        CurveValueProvider.CurvePool memory curvePool = curveValueProvider.getPoolInfo(THREE_CURVE_POOL_MAINNET_LP);

        assertEq(curvePool.pool, address(0));
        assertEq(curvePool.poolIdxMax, 0);
        // Array check reverts with `Index out of bounds`.
    }
}
