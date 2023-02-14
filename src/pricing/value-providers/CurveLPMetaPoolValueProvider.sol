// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProviderCurveLP } from "./base/BaseValueProviderCurveLP.sol";

import { ICurveRegistry } from "../../interfaces/external/curve/ICurveRegistry.sol";

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title Gets value of Curve MetaPool LP tokens.
 * @dev Value returned has 18 decimals of precision.
 */
contract CurveLPMetaPoolValueProvider is BaseValueProviderCurveLP {
    constructor(address _ethValueOracle) BaseValueProviderCurveLP(_ethValueOracle) { }

    function getPrice(address curveLpTokenToPrice) external view override onlyValueOracle returns (uint256) {
        ICurveRegistry registry = ICurveRegistry(CURVE_ADDRESS_PROVIDER.get_registry());

        address metaPool = registry.get_pool_from_lp_token(curveLpTokenToPrice);
        address[] memory poolCoins;
        //slither-disable-next-line uninitialized-local - This variable is always initiailized unless revert
        uint256[] memory poolBalances;
        // If statement takes care of all possible registery locations for metapools. Registry, two different factories
        if (metaPool == address(0)) {
            // Metapool lp tokens are only separate contracts in the case that the pool is not deployed by a factory.
            metaPool = curveLpTokenToPrice;
            poolCoins = _getDynamicArray(STABLE_AND_META_FACTORY.get_coins(metaPool));
            if (poolCoins[0] == address(0)) {
                poolCoins = _getDynamicArray(CURVE_METAPOOL_FACTORY.get_coins(metaPool));
                if (poolCoins[0] == address(0)) {
                    // All paths exhausted, throw error
                    revert CurvePoolNotRegistered(metaPool);
                } else {
                    poolBalances = _getDynamicArray(CURVE_METAPOOL_FACTORY.get_balances(metaPool));
                }
            } else {
                poolBalances = _getDynamicArray(STABLE_AND_META_FACTORY.get_balances(metaPool));
            }
        } else {
            poolCoins = _getDynamicArray(registry.get_coins(metaPool));
            poolBalances = _getDynamicArray(registry.get_balances(metaPool));
        }

        /// @dev Requires base pool to be registered in `EthValueOracle.sol` as well.
        uint256 metaPoolValueEth = _getCurvePoolValueEth(poolCoins, poolBalances);

        return _getPriceLp(metaPoolValueEth, IERC20Metadata(curveLpTokenToPrice));
    }
}
