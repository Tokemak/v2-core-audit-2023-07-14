// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProviderCurveLP } from "./base/BaseValueProviderCurveLP.sol";
import { ICurveRegistryV2 } from "../../interfaces/external/curve/ICurveRegistryV2.sol";
import { ICurveTokenV2 } from "../../interfaces/external/curve/ICurveTokenV2.sol";

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title Gets price of Curve Crypto / V2 LP tokens.
 * @dev Value returned has 18 decimals of precision.
 */
contract CurveLPV2ValueProvider is BaseValueProviderCurveLP {
    constructor(address _ethValueOracle) BaseValueProviderCurveLP(_ethValueOracle) { }

    function getPrice(address curveLpTokenToPrice) external view override onlyValueOracle returns (uint256) {
        // Index 5 is cryptoswap registry contract. See here:
        // https://curve.readthedocs.io/registry-address-provider.html#address-ids
        ICurveRegistryV2 registry = ICurveRegistryV2(CURVE_ADDRESS_PROVIDER.get_address(5));

        address pool = registry.get_pool_from_lp_token(curveLpTokenToPrice);
        address[] memory poolCoins;
        uint256[] memory poolBalances;
        if (pool == address(0)) {
            /**
             * V2 and up Curve tokens have public `minter()` attribute that allows for viewing pool address,
             *    V2 pools are not old enough to use V1 Curve token.
             */
            pool = ICurveTokenV2(curveLpTokenToPrice).minter();
            poolCoins = _getDynamicArray(CURVE_V2_FACTORY.get_coins(pool));
            poolBalances = _getDynamicArray(CURVE_V2_FACTORY.get_balances(pool));
        } else {
            poolCoins = _getDynamicArray(registry.get_coins(pool));
            poolBalances = _getDynamicArray(registry.get_balances(pool));
        }
        uint256 poolValueEth = _getCurvePoolValueEth(poolCoins, poolBalances);

        return _getPriceLp(poolValueEth, IERC20Metadata(curveLpTokenToPrice));
    }
}
