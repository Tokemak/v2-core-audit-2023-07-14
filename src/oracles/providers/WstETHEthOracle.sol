// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { IstEth } from "src/interfaces/external/lido/IstEth.sol";
import { IwstEth } from "src/interfaces/external/lido/IwstEth.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";

/// @title Price oracle specifically for wstETH
/// @dev getPriceEth is not a view fn to support reentrancy checks. Dont actually change state.
contract WstETHEthOracle is IPriceOracle {
    /// @notice The system this oracle will be registered with
    ISystemRegistry public immutable systemRegistry;

    IwstEth public immutable wstETH;
    IstEth public immutable stETH;
    uint256 public immutable stETHPrecision;

    error InvalidDecimals(address token, uint8 decimals);

    constructor(ISystemRegistry _systemRegistry, address _wstETH) {
        // System registry must be properly initialized first
        Errors.verifyNotZero(address(_systemRegistry), "_systemRegistry");
        Errors.verifyNotZero(address(_systemRegistry.rootPriceOracle()), "rootPriceOracle");

        Errors.verifyNotZero(address(_wstETH), "_wstETH");

        systemRegistry = _systemRegistry;

        wstETH = IwstEth(_wstETH);

        address stETHAddress = wstETH.stETH();
        Errors.verifyNotZero(stETHAddress, "stETHAddress");

        stETH = IstEth(stETHAddress);
        uint8 stETHDecimals = stETH.decimals();

        if (stETHDecimals == 0) {
            revert InvalidDecimals(stETHAddress, stETHDecimals);
        }
        stETHPrecision = 10 ** stETHDecimals;
    }

    /// @inheritdoc IPriceOracle
    function getPriceInEth(address token) external returns (uint256 price) {
        // This oracle is only setup to handle a single token but could possibly be
        // configured incorrectly at the root level and receive others to price.
        if (token != address(wstETH)) {
            revert Errors.InvalidToken(token);
        }

        uint256 stETHPrice = systemRegistry.rootPriceOracle().getPriceInEth(address(stETH));

        // Our prices are always in 1e18 so just use steths precision to get back to 1e18;
        price = (wstETH.stEthPerToken() * stETHPrice) / stETHPrecision;
    }

    function getSystemRegistry() external view returns (address registry) {
        return address(systemRegistry);
    }
}
