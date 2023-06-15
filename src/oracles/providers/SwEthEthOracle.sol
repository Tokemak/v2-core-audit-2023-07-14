// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { IswETH } from "src/interfaces/external/swell/IswETH.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";

/**
 * @notice Price oracle specifically for swEth (Swell Eth).
 * @dev getPriceEth is not a view fn to support reentrancy checks. Does not actually change state.
 */
contract SwEthEthOracle is IPriceOracle {
    ISystemRegistry public immutable systemRegistry;
    IswETH public immutable swEth;

    constructor(ISystemRegistry _systemRegistry, IswETH _swEth) {
        Errors.verifyNotZero(address(_systemRegistry), "_systemRegistry");
        Errors.verifyNotZero(address(_swEth), "_swEth");

        systemRegistry = _systemRegistry;
        swEth = _swEth;
    }

    /// @inheritdoc IPriceOracle
    function getPriceInEth(address token) external returns (uint256 price) {
        // Prevents incorrect config at root level.
        if (token != address(swEth)) revert Errors.InvalidToken(token);

        // Returns in 1e18 precision.
        price = swEth.swETHToETHRate();
    }

    function getSystemRegistry() external view returns (address registry) {
        return address(systemRegistry);
    }
}
