// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { ISfrxEth } from "src/interfaces/external/frax/ISfrxEth.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Price oracle specifically for sfrxETH
/// @dev getPriceEth is not a view fn to support reentrancy checks. Dont actually change state.
contract SfrxEthEthOracle is IPriceOracle {
    /// @notice The system this oracle will be registered with
    ISystemRegistry public immutable systemRegistry;

    ISfrxEth public immutable sfrxETH;
    IERC20Metadata public immutable frxETH;
    uint256 public immutable frxETHPrecision;

    error InvalidToken(address token);
    error InvalidDecimals(address token, uint8 decimals);

    constructor(ISystemRegistry _systemRegistry, address _sfrxETH) {
        // System registry must be properly initialized first
        Errors.verifyNotZero(address(_systemRegistry), "_systemRegistry");
        Errors.verifyNotZero(address(_systemRegistry.rootPriceOracle()), "rootPriceOracle");

        Errors.verifyNotZero(address(_sfrxETH), "_sfrxETH");

        systemRegistry = _systemRegistry;

        sfrxETH = ISfrxEth(_sfrxETH);

        address assetAddress = sfrxETH.asset();
        Errors.verifyNotZero(assetAddress, "assetAddress");

        frxETH = IERC20Metadata(assetAddress);
        uint8 frxETHDecimals = frxETH.decimals();

        if (frxETHDecimals == 0) {
            revert InvalidDecimals(address(frxETH), frxETHDecimals);
        }
        frxETHPrecision = 10 ** frxETHDecimals;
    }

    /// @inheritdoc IPriceOracle
    function getPriceInEth(address token) external returns (uint256 price) {
        // This oracle is only setup to handle a single token but could possibly be
        // configured incorrectly at the root level and receive others to price.
        if (token != address(sfrxETH)) {
            revert InvalidToken(token);
        }

        uint256 frxETHPrice = systemRegistry.rootPriceOracle().getPriceInEth(address(frxETH));

        // Our prices are always in 1e18 so just use frxETH precision to get back to 1e18;
        price = (sfrxETH.pricePerShare() * frxETHPrice) / frxETHPrecision;
    }

    function getSystemRegistry() external view returns (address registry) {
        return address(systemRegistry);
    }
}
