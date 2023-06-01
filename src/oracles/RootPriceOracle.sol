// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";

contract RootPriceOracle is SecurityBase, IRootPriceOracle {
    /// @notice The system this oracle will be registered with
    ISystemRegistry private immutable systemRegistry;

    mapping(address => IPriceOracle) public tokenMappings;

    event TokenRemoved(address token);
    event TokenRegistered(address token, address oracle);
    event TokenRegistrationReplaced(address token, address oldOracle, address newOracle);

    error AlreadyRegistered(address token);
    error MissingTokenOracle(address token);
    error MappingDoesNotExist(address token);
    error ReplaceOldMismatch(address token, address oldExpected, address oldActual);
    error ReplaceAlreadyMatches(address token, address newOracle);

    constructor(ISystemRegistry _systemRegistry) SecurityBase(address(_systemRegistry.accessController())) {
        Errors.verifyNotZero(address(_systemRegistry), "_systemRegistry");

        systemRegistry = _systemRegistry;
    }

    /// @notice Register a new token to oracle mapping
    /// @dev May require additional registration in the oracle itself
    /// @param token address of the token to register
    function registerMapping(address token, IPriceOracle oracle) external onlyOwner {
        Errors.verifyNotZero(token, "token");
        Errors.verifyNotZero(address(oracle), "oracle");
        Errors.verifySystemsMatch(this, oracle);

        // We want the operation of replacing a mapping to be an explicit
        // call so we don't accidentally overwrite something
        if (address(tokenMappings[token]) != address(0)) {
            revert AlreadyRegistered(token);
        }

        tokenMappings[token] = oracle;

        emit TokenRegistered(token, address(oracle));
    }

    /// @notice Replace an existing token -> oracle mapping
    /// @dev Must exist, matching existing, and new != old value to successfully replace
    /// @param token address of the token to register
    /// @param oldOracle existing oracle address
    /// @param newOracle new oracle address
    function replaceMapping(address token, IPriceOracle oldOracle, IPriceOracle newOracle) external onlyOwner {
        Errors.verifyNotZero(token, "token");
        Errors.verifyNotZero(address(oldOracle), "oldOracle");
        Errors.verifyNotZero(address(newOracle), "newOracle");
        Errors.verifySystemsMatch(this, newOracle);

        // We want to ensure you know what you're replacing so ensure
        // you provide a matching old value
        if (tokenMappings[token] != oldOracle) {
            revert ReplaceOldMismatch(token, address(oldOracle), address(tokenMappings[token]));
        }

        // If the old and new values match we can assume you're not doing
        // what you think you're doing so we just fail
        if (oldOracle == newOracle) {
            revert ReplaceAlreadyMatches(token, address(newOracle));
        }

        tokenMappings[token] = newOracle;

        emit TokenRegistrationReplaced(token, address(oldOracle), address(newOracle));
    }

    /// @notice Remove a token to oracle mapping
    /// @dev Must exist. Does not remove any additional configuration from the oracle itself
    /// @param token address of the token that is registered
    function removeMapping(address token) external onlyOwner {
        Errors.verifyNotZero(token, "token");

        // If you're trying to remove something that doesn't exist then
        // some condition you're expecting isn't true. We revert so you can reevaluate
        if (address(tokenMappings[token]) == address(0)) {
            revert MappingDoesNotExist(token);
        }

        delete tokenMappings[token];

        emit TokenRemoved(token);
    }

    /// @dev This and all price oracles are not view fn's so that we can perform the Curve reentrancy check
    /// @inheritdoc IRootPriceOracle
    function getPriceInEth(address token) external returns (uint256) {
        // Skip the token address(0) check and just rely on the oracle lookup
        // Emit token so we can figure out what was actually 0 later
        IPriceOracle oracle = tokenMappings[token];
        if (address(0) == address(oracle)) {
            revert MissingTokenOracle(token);
        }

        return oracle.getPriceInEth(token);
    }

    function getSystemRegistry() external view returns (address registry) {
        return address(systemRegistry);
    }
}
