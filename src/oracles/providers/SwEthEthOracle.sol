// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { IswETH } from "src/interfaces/external/swell/IswETH.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { SystemComponent } from "src/SystemComponent.sol";

/**
 * @notice Price oracle specifically for swEth (Swell Eth).
 * @dev getPriceEth is not a view fn to support reentrancy checks. Does not actually change state.
 */
contract SwEthEthOracle is SystemComponent, IPriceOracle {
    IswETH public immutable swEth;

    constructor(ISystemRegistry _systemRegistry, IswETH _swEth) SystemComponent(_systemRegistry) {
        Errors.verifyNotZero(address(_swEth), "_swEth");

        swEth = _swEth;
    }

    /// @inheritdoc IPriceOracle
    function getPriceInEth(address token) external view returns (uint256 price) {
        // Prevents incorrect config at root level.
        if (token != address(swEth)) revert Errors.InvalidToken(token);

        // Returns in 1e18 precision.
        price = swEth.swETHToETHRate();
    }
}
