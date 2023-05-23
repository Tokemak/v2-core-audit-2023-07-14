// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProviderLP, TokemakPricingPrecision } from "src/pricing/value-providers/base/BaseValueProviderLP.sol";
import { Errors } from "src/utils/Errors.sol";

import { IPool } from "src/interfaces/external/curve/IPool.sol";

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "forge-std/console.sol";

// solhint-disable func-name-mixedcase
// slither-disable-start calls-loop
/**
 * @title Contains functionality to register curve pools and get their prices.
 * @dev Returns 18 decimals of precision.
 */
contract CurveValueProvider is BaseValueProviderLP {
    /**
     * @notice Represents Curve pool.
     * @param poolIdxMax Number of tokens in pool.0
     * @param pool Address of pool.
     * @param tokensInPool Array of addresses of tokens in pool.
     */
    struct CurvePool {
        uint8 poolIdxMax; // Max 8, combines storage slot with pool address
        address pool;
        address[] tokensInPool;
    }

    /// @dev Mapping of lp token address to CruvePool struct.
    mapping(address => CurvePool) public pools;

    /// @notice Thrown when number of tokens submitted for pool exceeds actual number of tokens in pool.
    error MaxTokenIdxOutOfBounds();
    /// @notice Thrown when poolIdxMax is not greater than 1.
    error MustBeGTZero();
    /// @notice Thrown when attempting to overwrite existing declaration in `pools` mapping.
    error CurvePoolAlreadyRegistered();
    /// @notice Thrown when attempting to remove a pool that does not exist in `pools` mapping.
    error CurvePoolNotRegistered();

    /**
     * @notice Emitted when Curve pool added to `pools` mapping.
     * @param lpToken Address of lp token registered.
     * @param pool Address of pool registered.
     */
    event CurvePoolRegistered(address lpToken, address pool);

    /**
     * @notice Emitted when a Curve pool is removed from `pools` mapping.
     * @param lpToken Address of lp token removed.
     * @param pool Address of pool removed.
     */
    event CurvePoolRemoved(address lpToken, address pool);

    constructor(address _ethValueOracle) BaseValueProviderLP(_ethValueOracle) { }

    /**
     * @notice Getter for `CurvePool` struct.
     * @param lpToken Address of lp token to get info for.
     */
    function getPoolInfo(address lpToken) external view returns (CurvePool memory) {
        return pools[lpToken];
    }

    /**
     * @notice Used to register Curve pools and lp tokens to price.
     * @dev privileged access.
     * @param lpToken Address of lp token to get price for.
     * @param pool Address of corresponding pool.
     * @param poolIdxMax Max index for `coins()` and `balances()` array on Curve pool. Total number of
     *      coins in pool - 1.
     */
    function registerCurveLPToken(address lpToken, address pool, uint8 poolIdxMax) external onlyOwner {
        Errors.verifyNotZero(lpToken, "lpToken");
        Errors.verifyNotZero(pool, "pool");
        if (poolIdxMax == 0) revert MustBeGTZero();

        // No unintended overwrites.
        if (pools[lpToken].pool != address(0)) revert CurvePoolAlreadyRegistered();
        IPool curvePool = IPool(pool);

        /**
         * Check to see if `poolIdxMax` is greater than max number of tokens in pool,
         *      catch generic EVM revert thrown, throw custom error.  `coins()` throws
         *      general evm revert when index is out of bounds. Adjusts for coins starting
         *      at index 0,
         *
         * Error thrown by `coins()`: `Error: Returned error: execution reverted`.
         */
        // slither-disable-next-line unused-return
        try curvePool.coins(poolIdxMax) { }
        catch (bytes memory) {
            revert MaxTokenIdxOutOfBounds();
        }

        /**
         * Get array of pool tokens to save to CurvePool struct in storage. Need
         *    poolIdxMax + 1 to account for total tokens in array.
         */
        address[] memory tokensInPool = new address[](poolIdxMax + 1);
        for (uint256 i = 0; i <= poolIdxMax; ++i) {
            tokensInPool[i] = curvePool.coins(i);
        }
        pools[lpToken] = CurvePool(poolIdxMax, pool, tokensInPool);
        pools[lpToken].tokensInPool = tokensInPool;

        emit CurvePoolRegistered(lpToken, pool);
    }

    /**
     * @notice Used to remove Curve pool from `pools` mapping
     * @dev Privileged access.
     * @dev Removal will result in inability to price lp of corresponding pool.
     * @param lpToken Address of lp token to remove pool for.
     */
    function removeCurveLPToken(address lpToken) external onlyOwner {
        Errors.verifyNotZero(lpToken, "lpToken");
        address poolBeforeDeletion = pools[lpToken].pool;
        if (poolBeforeDeletion == address(0)) revert CurvePoolNotRegistered();

        delete pools[lpToken];
        emit CurvePoolRemoved(lpToken, poolBeforeDeletion);
    }

    /// @dev Base pools for any metapools priced must be registered here and in `EthValueOracle.sol`.
    function getPrice(address curveLpTokenToPrice) external view override onlyValueOracle returns (uint256) {
        address pool = pools[curveLpTokenToPrice].pool;
        uint8 poolIdxMax = pools[curveLpTokenToPrice].poolIdxMax;
        address[] memory poolCoins = pools[curveLpTokenToPrice].tokensInPool;

        if (pool == address(0)) revert CurvePoolNotRegistered();

        // Get balances array. Need poolIdxMax + 1 to account for total tokens in array.
        uint256[] memory balances = new uint256[](poolIdxMax + 1);
        for (uint256 i = 0; i <= poolIdxMax; ++i) {
            balances[i] = IPool(pool).balances(i);
        }

        // 1e36 precision, taken care of in `_getPriceLp()`.
        uint256 poolValueEth;
        // Get price value in pool per token
        for (uint256 i = 0; i <= poolIdxMax; ++i) {
            address currentToken = poolCoins[i];
            uint256 normalizedBalance = TokemakPricingPrecision.checkAndNormalizeDecimals(
                TokemakPricingPrecision.getDecimals(currentToken), balances[i]
            );
            poolValueEth += ethValueOracle.getPrice(currentToken, TokemakPricingPrecision.STANDARD_PRECISION, true)
                * normalizedBalance;
        }

        return _getPriceLp(poolValueEth, IERC20Metadata(curveLpTokenToPrice));
    }
}
// slither-disable-end calls-loop
