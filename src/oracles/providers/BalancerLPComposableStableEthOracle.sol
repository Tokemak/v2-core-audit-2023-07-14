// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { BalancerUtilities } from "src/libs/BalancerUtilities.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IVault as IBalancerVault } from "src/interfaces/external/balancer/IVault.sol";
import { IBalancerComposableStablePool } from "src/interfaces/external/balancer/IBalancerComposableStablePool.sol";

/// @title Price oracle for Balancer Composable Stable pools
/// @dev getPriceEth is not a view fn to support reentrancy checks. Dont actually change state.
contract BalancerLPComposableStableEthOracle is IPriceOracle {
    /// @notice The system this oracle will be registered with
    ISystemRegistry public immutable systemRegistry;

    /// @notice The Balancer Vault that all tokens we're resolving here should reference
    /// @dev BPTs themselves are configured with an immutable vault reference
    IBalancerVault public immutable balancerVault;

    error InvalidPrice(address token, uint256 price);

    constructor(ISystemRegistry _systemRegistry, IBalancerVault _balancerVault) {
        // System registry must be properly initialized first
        Errors.verifyNotZero(address(_systemRegistry), "_systemRegistry");
        Errors.verifyNotZero(address(_systemRegistry.rootPriceOracle()), "rootPriceOracle");

        Errors.verifyNotZero(address(_balancerVault), "_balancerVault");

        systemRegistry = _systemRegistry;
        balancerVault = _balancerVault;
    }

    /// @inheritdoc IPriceOracle
    function getPriceInEth(address token) external returns (uint256 price) {
        Errors.verifyNotZero(token, "token");

        BalancerUtilities.checkReentrancy(address(balancerVault));

        IBalancerComposableStablePool pool = IBalancerComposableStablePool(token);
        bytes32 poolId = pool.getPoolId();

        // Will revert with BAL#500 on invalid pool id
        (IERC20[] memory tokens,,) = balancerVault.getPoolTokens(poolId);

        uint256 bptIndex = pool.getBptIndex();
        uint256 minPrice = type(uint256).max;
        uint256 nTokens = tokens.length;

        for (uint256 i = 0; i < nTokens;) {
            if (i != bptIndex) {
                // Our prices are always in 1e18
                // slither-disable-next-line calls-loop
                uint256 tokenPrice = systemRegistry.rootPriceOracle().getPriceInEth(address(tokens[i]));
                if (tokenPrice < minPrice) {
                    minPrice = tokenPrice;
                }
            }

            unchecked {
                ++i;
            }
        }

        // If it's still the default vault we set, something went wrong
        if (minPrice == type(uint256).max) {
            revert InvalidPrice(token, type(uint256).max);
        }

        // Intentional precision loss, prices should always be in e18
        // slither-disable-next-line divide-before-multiply
        price = (minPrice * pool.getRate()) / 1e18;
    }

    function getSystemRegistry() external view returns (address registry) {
        return address(systemRegistry);
    }
}
