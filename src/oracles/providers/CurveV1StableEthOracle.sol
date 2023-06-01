// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { ICurveResolver } from "src/interfaces/utils/ICurveResolver.sol";
import { ICurveOwner } from "src/interfaces/external/curve/ICurveOwner.sol";
import { ICurveStableSwap } from "src/interfaces/external/curve/ICurveStableSwap.sol";

/// @title Price oracle for Curve StableSwap pools
/// @dev getPriceEth is not a view fn to support reentrancy checks. Dont actually change state.
contract CurveV1StableEthOracle is SecurityBase, IPriceOracle {
    bytes32 public constant LOCK_REVERT_MSG = keccak256(abi.encode("lock"));

    /// @notice The system this oracle will be registered with
    ISystemRegistry public immutable systemRegistry;

    ICurveResolver public immutable curveResolver;

    struct PoolData {
        address pool;
        uint8 checkReentrancy;
    }

    event TokenRegistered(address lpToken);
    event TokenUnregistered(address lpToken);

    error NotStableSwap(address curvePool);
    error NotRegistered(address curveLpToken);
    error InvalidPrice(address token, uint256 price);
    error ResolverMismatch(address providedLP, address queriedLP);
    error ReadonlyReentrancy(address curvePool);

    /// @notice Curve LP tokens and their underlying tokens
    /// @dev lpToken => erc20[]
    mapping(address => address[]) public lpTokenToUnderlying;

    /// @notice Reverse mapping of LP token to pool info
    mapping(address => PoolData) public lpTokenToPool;

    constructor(
        ISystemRegistry _systemRegistry,
        ICurveResolver _curveResolver
    ) SecurityBase(address(_systemRegistry.accessController())) {
        // System registry must be properly initialized first
        Errors.verifyNotZero(address(_systemRegistry), "_systemRegistry");
        Errors.verifyNotZero(address(_systemRegistry.rootPriceOracle()), "rootPriceOracle");

        Errors.verifyNotZero(address(_curveResolver), "_curveResolver");

        systemRegistry = _systemRegistry;
        curveResolver = _curveResolver;
    }

    /// @notice Register a Curve LP token to this oracle
    /// @dev Double checks pool+lp against on-chain query. Only use with StableSwap pools.
    /// @param curvePool address of the Curve pool related to the LP token
    /// @param curveLpToken address of the LP token we'll be looking up prices for
    /// @param checkReentrancy whether or not we should check for read-only reentrancy
    function registerPool(address curvePool, address curveLpToken, bool checkReentrancy) external onlyOwner {
        Errors.verifyNotZero(curvePool, "curvePool");
        Errors.verifyNotZero(curveLpToken, "curveLpToken");

        (address[8] memory tokens, uint256 numTokens, address lpToken, bool isStableSwap) =
            curveResolver.resolveWithLpToken(curvePool);

        // This oracle uses the min-price approach for finding the current value of tokens
        // and only applies to stable swap pools. The resolver will resolve both stable and
        // crypto swap pools so we want to be sure only the correct type gets in.
        if (!isStableSwap) {
            revert NotStableSwap(curvePool);
        }

        // Make sure the data we were working with off-chain during registration matches
        // what we get if we query it on-chain, expectation check
        if (lpToken != curveLpToken) {
            revert ResolverMismatch(curveLpToken, lpToken);
        }

        for (uint256 i = 0; i < numTokens;) {
            lpTokenToUnderlying[lpToken].push(tokens[i]);

            unchecked {
                ++i;
            }
        }
        lpTokenToPool[lpToken] = PoolData({ pool: curvePool, checkReentrancy: checkReentrancy ? 1 : 0 });

        emit TokenRegistered(lpToken);
    }

    /// @notice Unregister a Curve Lp token from the oracle
    /// @dev Must already exist. More lenient than register with expectation checks, it's already in,
    /// assume you know what you're doing
    /// @param curveLpToken token to unregister
    function unregister(address curveLpToken) external onlyOwner {
        Errors.verifyNotZero(curveLpToken, "curveLpToken");

        // You're calling unregister so you're expecting it to be here
        // Stopping if not so you can reevaluate
        if (lpTokenToUnderlying[curveLpToken].length == 0) {
            revert NotRegistered(curveLpToken);
        }

        delete lpTokenToUnderlying[curveLpToken];
        delete lpTokenToPool[curveLpToken];

        emit TokenUnregistered(curveLpToken);
    }

    /// @inheritdoc IPriceOracle
    function getPriceInEth(address token) external returns (uint256 price) {
        Errors.verifyNotZero(token, "token");

        address[] memory tokens = lpTokenToUnderlying[token];

        uint256 minPrice = type(uint256).max;
        uint256 nTokens = tokens.length;

        if (nTokens == 0) {
            revert NotRegistered(token);
        }

        PoolData memory poolInfo = lpTokenToPool[token];
        ICurveStableSwap pool = ICurveStableSwap(poolInfo.pool);

        for (uint256 i = 0; i < nTokens;) {
            address iToken = tokens[i];

            // We're in a V1 ETH pool and we'll be reading the virtual price later
            // make sure we're not in a read-only reentrancy scenario
            if (iToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                if (poolInfo.checkReentrancy == 1) {
                    // This will fail in reentrancy
                    // slither-disable-next-line calls-loop
                    ICurveOwner(pool.owner()).withdraw_admin_fees(address(pool));
                }
            }

            // Our prices are always in 1e18
            // slither-disable-next-line calls-loop
            uint256 tokenPrice = systemRegistry.rootPriceOracle().getPriceInEth(iToken);
            if (tokenPrice < minPrice) {
                minPrice = tokenPrice;
            }

            unchecked {
                ++i;
            }
        }

        // If it's still the default price we set, something went wrong
        if (minPrice == type(uint256).max) {
            revert InvalidPrice(token, type(uint256).max);
        }

        price = (minPrice * pool.get_virtual_price() / 1e18);
    }

    function getSystemRegistry() external view returns (address registry) {
        return address(systemRegistry);
    }

    function getLpTokenToUnderlying(address lpToken) external view returns (address[] memory tokens) {
        uint256 len = lpTokenToUnderlying[lpToken].length;
        tokens = new address[](len);

        for (uint256 i = 0; i < len; i++) {
            tokens[i] = lpTokenToUnderlying[lpToken][i];
        }
    }
}
