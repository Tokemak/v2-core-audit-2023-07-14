// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";
import { Math } from "openzeppelin-contracts/utils/math/Math.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { IUniswapV2Pair } from "src/interfaces/external/uniswap/IUniswapV2Pair.sol";
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SystemComponent } from "src/SystemComponent.sol";

/// @title Price oracle for Uni V2 style, 50/50 pools
/// @dev getPriceEth is not a view fn to support reentrancy checks. Dont actually change state.
contract UniswapV2EthOracle is SystemComponent, SecurityBase, IPriceOracle {
    struct PairRegistration {
        address token0;
        uint96 numeratorPad;
        address token1;
        uint96 denominatorPad;
    }

    /// @notice Tokens registered with this oracle. Only registered tokens can be used.
    /// @dev pairAddress -> registration
    mapping(address => PairRegistration) public registrations;

    event PairRegistered(address pair, address token0, address token1, uint8 totalDecimals);
    event PairUnregistered(address pair);

    error InvalidDecimals(uint8 decimals);
    error NotRegistered(address pairAddress);

    constructor(ISystemRegistry _systemRegistry)
        SystemComponent(_systemRegistry)
        SecurityBase(address(_systemRegistry.accessController()))
    {
        // System registry must be properly initialized first
        Errors.verifyNotZero(address(_systemRegistry.rootPriceOracle()), "rootPriceOracle");
    }

    function register(address pairAddress) external onlyOwner {
        Errors.verifyNotZero(pairAddress, "pairAddress");
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        address token0 = pair.token0();
        address token1 = pair.token1();
        Errors.verifyNotZero(token0, "token0");
        Errors.verifyNotZero(token1, "token1");

        uint8 totalDecimals = IERC20Metadata(token0).decimals() + IERC20Metadata(token1).decimals();

        // Not dealing with an odd total decimals as it's just an unlikely scenario
        if (totalDecimals % 2 != 0) {
            revert InvalidDecimals(totalDecimals);
        }

        // Price should be in e18. If a tokens are less than 18 pad numerator. Greater than, pad denominator
        uint96 numeratorPad = 1;
        uint96 denominatorPad = 1;
        if (totalDecimals > 36) {
            denominatorPad = uint96(10 ** ((totalDecimals - 36) / 2));
        } else if (totalDecimals < 36) {
            numeratorPad = uint96(10 ** (36 - totalDecimals));
        }

        registrations[pairAddress] = PairRegistration({
            numeratorPad: numeratorPad,
            denominatorPad: denominatorPad,
            token0: token0,
            token1: token1
        });

        emit PairRegistered(pairAddress, token0, token1, totalDecimals);
    }

    function unregister(address pairAddress) external onlyOwner {
        Errors.verifyNotZero(pairAddress, "pairAddress");

        // You're calling unregister so you're expecting it to be here
        // Stopping if not so you can reevaluate
        if (registrations[pairAddress].token0 == address(0)) {
            revert NotRegistered(pairAddress);
        }

        delete registrations[pairAddress];

        emit PairUnregistered(pairAddress);
    }

    /// @inheritdoc IPriceOracle
    function getPriceInEth(address token) external returns (uint256 price) {
        IUniswapV2Pair pair = IUniswapV2Pair(token);

        PairRegistration memory registration = registrations[token];
        Errors.verifyNotZero(registration.token0, "registration.token0");

        uint256 totalSupply = pair.totalSupply();

        uint256 px0 = systemRegistry.rootPriceOracle().getPriceInEth(registration.token0);
        uint256 px1 = systemRegistry.rootPriceOracle().getPriceInEth(registration.token1);
        (uint256 reserve0, uint256 reserve1) = _getReserves(token);
        uint256 sqR = Math.sqrt(uint256(reserve0) * uint256(reserve1) * registration.numeratorPad); // >= e18
        uint256 sqP = Math.sqrt(px0 * px1); // e18
        uint256 value = (2 * sqR * sqP); // >= e36
        uint256 scaledSupply = (totalSupply * registration.denominatorPad); // >= e18, < e36
        price = value / scaledSupply; // e18
    }

    function _getReserves(address token) internal view virtual returns (uint256 reserve0, uint256 reserve1) {
        // Partial return values are intentionally ignored. This call provides the most efficient way to get the data.
        // slither-disable-next-line unused-return
        (reserve0, reserve1,) = IUniswapV2Pair(token).getReserves();
    }
}
