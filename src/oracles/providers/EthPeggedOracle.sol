// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";

/// @title Price oracle for tokens we want to configure 1:1 to ETH. WETH for example
/// @dev getPriceEth is not a view fn to support reentrancy checks. Dont actually change state.
contract EthPeggedOracle is IPriceOracle {
    /// @notice The system this oracle will be registered with
    ISystemRegistry public immutable systemRegistry;

    constructor(ISystemRegistry _systemRegistry) {
        // System registry must be properly initialized first
        Errors.verifyNotZero(address(_systemRegistry), "_systemRegistry");

        systemRegistry = _systemRegistry;
    }

    /// @inheritdoc IPriceOracle
    function getPriceEth(address) external returns (uint256 price) {
        price = 1e18;
    }

    function getSystemRegistry() external view returns (address registry) {
        return address(systemRegistry);
    }
}
