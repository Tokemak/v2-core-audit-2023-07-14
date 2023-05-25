// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProviderLP, TokemakPricingPrecision } from "src/pricing/value-providers/base/BaseValueProviderLP.sol";
import { Errors } from "src/utils/Errors.sol";

import { IPool } from "src/interfaces/external/curve/IPool.sol";
import { ICurveRegistry } from "src/interfaces/external/curve/ICurveRegistry.sol";
import { ICurveRegistryV2 } from "src/interfaces/external/curve/ICurveRegistryV2.sol";
import { ICurveMetaStableFactory } from "src/interfaces/external/curve/ICurveMetaStableFactory.sol";
import { ICurveMetaPoolFactory } from "src/interfaces/external/curve/ICurveMetaPoolFactory.sol";
import { ICurveFactoryV2 } from "src/interfaces/external/curve/ICurveFactoryV2.sol";
import { ICurveTokenV2 } from "src/interfaces/external/curve/ICurveTokenV2.sol";

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

// solhint-disable func-name-mixedcase
// slither-disable-start calls-loop
/**
 * @title Contains functionality to register curve pools and get their prices.
 * @dev Returns 18 decimals of precision.
 */
contract CurveValueProvider is BaseValueProviderLP {
    /// @notice Used to determine where pool is registered.
    enum PoolRegistryLocation {
        MetaStableRegistry,
        MetaStableFactory,
        MetaPoolFactory,
        V2Registry,
        V2Factory
    }

    /**
     * @notice Represents Curve pool.
     * @param poolIdxMax Number of tokens in pool.
     * @param pool Address of pool.
     * @param tokensInPool Array of addresses of tokens in pool.
     */
    struct CurvePool {
        uint8 numCoins; // Max 8, combines storage slot with pool address
        address pool;
        address[] tokensInPool;
    }

    // Addresses of Curve registries and factories.
    ICurveRegistry public constant REGISTRY = ICurveRegistry(0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f5);
    ICurveRegistryV2 public constant V2_REGISTRY = ICurveRegistryV2(0x8F942C20D02bEfc377D41445793068908E2250D0);
    ICurveMetaStableFactory public constant META_STABLE_FACTORY =
        ICurveMetaStableFactory(0xB9fC157394Af804a3578134A6585C0dc9cc990d4);
    ICurveMetaPoolFactory public constant META_FACTORY =
        ICurveMetaPoolFactory(0x0959158b6040D32d04c301A72CBFD6b39E21c9AE);
    ICurveFactoryV2 public constant V2_FACTORY = ICurveFactoryV2(0xF18056Bbd320E96A48e3Fbf8bC061322531aac99);

    /// @dev Mapping of lp token address to CruvePool struct.
    mapping(address => CurvePool) public pools;

    /// @notice Thrown when attempting to overwrite existing declaration in `pools` mapping.
    error CurvePoolAlreadyRegistered();
    /// @notice Thrown when attempting to remove a pool that does not exist in `pools` mapping.
    error CurvePoolNotRegistered();
    /// @notice Thrown when token read from pool does not match token registered.
    error TokenMismatch();

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
     * @dev Must determine where token is registered manually.  See addresses for various registries above
     *      use `get_lp_token` if pool is not erc20 and check `get_coins()`. If non-zero values are returned
     *      that registry can be used.
     * @param lpToken Address of lp token to get price for.
     */
    function registerCurveLPToken(address lpToken, PoolRegistryLocation registry) external onlyOwner {
        Errors.verifyNotZero(lpToken, "lpToken");
        if (pools[lpToken].pool != address(0)) revert CurvePoolAlreadyRegistered();

        address pool; // For event
        if (registry == PoolRegistryLocation.MetaStableRegistry) {
            pool = REGISTRY.get_pool_from_lp_token(lpToken);
            Errors.verifyNotZero(pool, "pool");
            pools[lpToken] = CurvePool({
                numCoins: uint8(REGISTRY.get_n_coins(pool)[0]),
                pool: pool,
                tokensInPool: _getDynamicArray(REGISTRY.get_coins(pool))
            });
        } else if (registry == PoolRegistryLocation.MetaStableFactory) {
            address[] memory poolCoins = _getDynamicArray(META_STABLE_FACTORY.get_coins(lpToken));
            Errors.verifyNotZero(poolCoins[0], "poolCoinsSlotZero");
            pool = lpToken;
            pools[lpToken] = CurvePool({
                numCoins: uint8(META_STABLE_FACTORY.get_n_coins(lpToken)),
                pool: lpToken, // lpToken == pool address for factory deployed meta and stable pools.
                tokensInPool: poolCoins
            });
        } else if (registry == PoolRegistryLocation.MetaPoolFactory) {
            address[] memory poolCoins = _getDynamicArray(META_FACTORY.get_coins(lpToken));
            Errors.verifyNotZero(poolCoins[0], "poolCoinsSlotZero");
            pool = lpToken;
            pools[lpToken] = CurvePool({
                numCoins: 2, // Same for all pools in this factory.
                pool: lpToken,
                tokensInPool: poolCoins
            });
        } else if (registry == PoolRegistryLocation.V2Registry) {
            pool = ICurveTokenV2(lpToken).minter();
            Errors.verifyNotZero(pool, "pool");

            address[] memory poolCoins = _getDynamicArray(V2_REGISTRY.get_coins(pool));
            Errors.verifyNotZero(poolCoins[0], "poolCoinsSlotZero");

            pools[lpToken] =
                CurvePool({ numCoins: uint8(V2_REGISTRY.get_n_coins(pool)), pool: pool, tokensInPool: poolCoins });
        } else if (registry == PoolRegistryLocation.V2Factory) {
            pool = ICurveTokenV2(lpToken).minter();
            Errors.verifyNotZero(pool, "pool");

            address[] memory poolCoins = _getDynamicArray(V2_FACTORY.get_coins(pool));
            Errors.verifyNotZero(poolCoins[0], "PoolCoinsSlotZero");

            pools[lpToken] = CurvePool({
                numCoins: 2, // Always two from this factory.
                pool: pool,
                tokensInPool: poolCoins
            });
        }

        emit CurvePoolRegistered(lpToken, pool);
    }

    /**
     * @notice Used to remove Curve pool from `pools` mapping
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
        CurvePool memory curvePool = pools[curveLpTokenToPrice];

        if (curvePool.pool == address(0)) revert CurvePoolNotRegistered();

        uint256[] memory balances = new uint256[](curvePool.numCoins);
        for (uint256 i = 0; i < curvePool.numCoins; ++i) {
            IPool pool = IPool(curvePool.pool);
            if (curvePool.tokensInPool[i] != pool.coins(i)) revert TokenMismatch();
            balances[i] = pool.balances(i);
        }

        // 1e36 precision, taken care of in `_getPriceLp()`.
        uint256 poolValueEth;
        // Get price value in pool per token
        for (uint256 i = 0; i < curvePool.numCoins; ++i) {
            address currentToken = curvePool.tokensInPool[i];
            uint256 currentTokenDecimals = TokemakPricingPrecision.getDecimals(currentToken);
            uint256 normalizedBalance =
                TokemakPricingPrecision.checkAndNormalizeDecimals(currentTokenDecimals, balances[i]);
            poolValueEth += ethValueOracle.getPrice(currentToken, TokemakPricingPrecision.STANDARD_PRECISION, true)
                * normalizedBalance;
        }

        return _getPriceLp(poolValueEth, IERC20Metadata(curveLpTokenToPrice));
    }

    /**
     * Helper functions for various static arrays returned by Curve registries and factories.
     */

    function _getDynamicArray(address[2] memory twoMemberStaticAddressArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](2);

        for (uint256 i = 0; i < 2; ++i) {
            dynamicArray[i] = twoMemberStaticAddressArray[i];
        }
        return dynamicArray;
    }

    function _getDynamicArray(address[4] memory fourMemberStaticAddressArray)
        internal
        pure
        returns (address[] memory dynamicAddressArray)
    {
        address[] memory dynamicArray = new address[](4);

        for (uint256 i = 0; i < 4; ++i) {
            address currentAddress = fourMemberStaticAddressArray[i];
            // No need to set zero address
            if (currentAddress == address(0)) break;
            dynamicArray[i] = currentAddress;
        }
        return dynamicArray;
    }

    function _getDynamicArray(address[8] memory eightMemberStaticAddressArray)
        internal
        pure
        returns (address[] memory)
    {
        address[] memory dynamicArray = new address[](8);

        for (uint256 i = 0; i < 8; ++i) {
            address currentAddress = eightMemberStaticAddressArray[i];
            if (currentAddress == address(0)) break;
            dynamicArray[i] = currentAddress;
        }
        return dynamicArray;
    }
}
// slither-disable-end calls-loop
