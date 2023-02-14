// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProviderCurveLP } from "./base/BaseValueProviderCurveLP.sol";

import { ICurveRegistry } from "../../interfaces/external/curve/ICurveRegistry.sol";

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title Gets price of Curve StableSwap pool LP tokens.
 * @dev Value returned has 18 decimals of precision.
 */
contract CurveLPValueProvider is BaseValueProviderCurveLP {
    constructor(address _ethValueOracle) BaseValueProviderCurveLP(_ethValueOracle) { }

    function getPrice(address curveLpTokenToPrice) external view override onlyValueOracle returns (uint256) {
        ICurveRegistry registry = ICurveRegistry(CURVE_ADDRESS_PROVIDER.get_registry());

        address pool = registry.get_pool_from_lp_token(curveLpTokenToPrice);
        address[] memory poolCoins;
        uint256[] memory poolBalances;
        if (pool == address(0)) {
            // Metapool and stableswap pools deployed from factory have lp embedded in contract.
            pool = curveLpTokenToPrice;
            poolCoins = _getDynamicArray(STABLE_AND_META_FACTORY.get_coins(pool));
            poolBalances = _getDynamicArray(STABLE_AND_META_FACTORY.get_balances(pool));
        } else {
            poolCoins = _getDynamicArray(registry.get_coins(pool));
            poolBalances = _getDynamicArray(registry.get_balances(pool));
        }
        uint256 poolValueEth = _getCurvePoolValueEth(poolCoins, poolBalances);

        return _getPriceLp(poolValueEth, IERC20Metadata(curveLpTokenToPrice));
    }
}
