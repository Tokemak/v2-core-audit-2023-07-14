// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { AccessController } from "src/security/AccessController.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";
import { UniswapV2EthOracle } from "src/oracles/providers/UniswapV2EthOracle.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";
import { IUniswapV2Pair } from "src/interfaces/external/uniswap/IUniswapV2Pair.sol";
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract UniswapV2EthOracleTests is Test {
    uint256 private _addrIx;

    IRootPriceOracle private _rootPriceOracle;
    ISystemRegistry private _systemRegistry;
    IAccessController private _accessController;
    UniswapV2EthOracle private _oracle;

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 17_269_656);
        vm.selectFork(mainnetFork);

        _systemRegistry = ISystemRegistry(vm.addr(34_343));
        _rootPriceOracle = IRootPriceOracle(vm.addr(324));
        _accessController = new AccessController(address(_systemRegistry));
        _generateSystemRegistry(address(_systemRegistry), address(_accessController), address(_rootPriceOracle));
        _oracle = new UniswapV2EthOracle(_systemRegistry);

        // Ensure the onlyOwner call passes
        _accessController.grantRole(0x00, address(this));
    }

    function testRegistrationSecurity() public {
        address mockPool = vm.addr(25);

        address testUser1 = vm.addr(34_343);
        vm.prank(testUser1);

        vm.expectRevert(abi.encodeWithSelector(IAccessController.AccessDenied.selector));
        _oracle.register(mockPool);
    }

    function testSimplePrice() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(18);
        address token1 = _generateToken(18);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e18;
        uint112 reserve1 = 10e18;
        uint256 price0 = 1e18;
        uint256 price1 = 1e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertEq(price, 20e18);
    }

    function testToken0LessThan18Decimals() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(6);
        address token1 = _generateToken(18);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e6;
        uint112 reserve1 = 10e18;
        uint256 price0 = 1e18;
        uint256 price1 = 1e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertEq(price, 20e18);
    }

    function testOddTotalDecimalsBlocked() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(19);
        address token1 = _generateToken(18);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e19;
        uint112 reserve1 = 10e17;
        uint256 price0 = 1e18;
        uint256 price1 = 1e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);

        vm.expectRevert(abi.encodeWithSelector(UniswapV2EthOracle.InvalidDecimals.selector, 19 + 18));
        _oracle.register(pool);
    }

    function testDoubleOddDecimalsCanRegister() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(7);
        address token1 = _generateToken(19);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e7;
        uint112 reserve1 = 10e19;
        uint256 price0 = 1e18;
        uint256 price1 = 1e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertEq(price, 20e18);
    }

    function testToken1LessThan18Decimals() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(18);
        address token1 = _generateToken(6);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e18;
        uint112 reserve1 = 10e6;
        uint256 price0 = 1e18;
        uint256 price1 = 1e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertEq(price, 20e18);
    }

    function testToken0GreaterThan18Decimals() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(24);
        address token1 = _generateToken(18);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e24;
        uint112 reserve1 = 10e18;
        uint256 price0 = 1e18;
        uint256 price1 = 1e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertEq(price, 20e18);
    }

    function testToken01GreaterThan18Decimals() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(24);
        address token1 = _generateToken(24);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e24;
        uint112 reserve1 = 10e24;
        uint256 price0 = 1e18;
        uint256 price1 = 1e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertEq(price, 20e18);
    }

    function testToken0MaxDecimals() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(32);
        address token1 = _generateToken(18);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e32;
        uint112 reserve1 = 10e18;
        uint256 price0 = 1e18;
        uint256 price1 = 1e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertEq(price, 20e18);
    }

    function testToken1MaxDecimals() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(18);
        address token1 = _generateToken(32);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e18;
        uint112 reserve1 = 10e32;
        uint256 price0 = 1e18;
        uint256 price1 = 1e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertEq(price, 20e18);
    }

    function testToken01MaxDecimals() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(32);
        address token1 = _generateToken(32);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e32;
        uint112 reserve1 = 10e32;
        uint256 price0 = 1e18;
        uint256 price1 = 1e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertEq(price, 20e18);
    }

    function testPriceIsInlineWhenReservesMatchPrices() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(18);
        address token1 = _generateToken(18);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e18;
        uint112 reserve1 = 20e18;
        uint256 price0 = 1e18;
        uint256 price1 = 2e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertApproxEqAbs(price, 40e18, 1e6);
    }

    function testPriceSkewsLowWhenReservesMismatch() public {
        address pool = vm.addr(10);
        address token0 = _generateToken(18);
        address token1 = _generateToken(18);
        uint256 totalSupply = 1e18;
        uint112 reserve0 = 10e18;
        uint112 reserve1 = 15e18; // 20e18 would be a match
        uint256 price0 = 1e18;
        uint256 price1 = 2e18;

        _mockRootPrice(token0, price0);
        _mockRootPrice(token1, price1);
        _mockUniV2Pool(pool, token0, token1, totalSupply, reserve0, reserve1);
        _oracle.register(pool);

        uint256 price = _oracle.getPriceInEth(pool);

        assertApproxEqAbs(price, 35e18, 1e18);
    }

    function _mockUniV2Pool(
        address pool,
        address token0,
        address token1,
        uint256 totalSupply,
        uint112 reserve0,
        uint112 reserve1
    ) internal {
        //token0()
        vm.mockCall(pool, abi.encodeWithSelector(IUniswapV2Pair.token0.selector), abi.encode(token0));

        //token1()
        vm.mockCall(pool, abi.encodeWithSelector(IUniswapV2Pair.token1.selector), abi.encode(token1));

        //totalSupply()
        vm.mockCall(pool, abi.encodeWithSelector(IUniswapV2Pair.totalSupply.selector), abi.encode(totalSupply));

        //getReserves()
        uint32 ts = 9;
        bytes memory data = abi.encode(reserve0, reserve1, ts);
        vm.mockCall(pool, abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector), data);
    }

    function _generateToken(uint8 decimals) internal returns (address) {
        address addr = vm.addr(239_874 + _addrIx++);
        vm.mockCall(addr, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(decimals));
        return addr;
    }

    function _mockRootPrice(address token, uint256 price) internal {
        vm.mockCall(
            address(_rootPriceOracle),
            abi.encodeWithSelector(IRootPriceOracle.getPriceInEth.selector, token),
            abi.encode(price)
        );
    }

    function _generateSystemRegistry(address registry, address accessControl, address rootOracle) internal {
        vm.mockCall(registry, abi.encodeWithSelector(ISystemRegistry.rootPriceOracle.selector), abi.encode(rootOracle));

        vm.mockCall(
            registry, abi.encodeWithSelector(ISystemRegistry.accessController.selector), abi.encode(accessControl)
        );
    }
}
