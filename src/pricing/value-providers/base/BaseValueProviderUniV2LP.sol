// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProviderLP, IERC20Metadata, TokemakPricingPrecision } from "./BaseValueProviderLP.sol";
import { IPairUniV2 } from "../../../interfaces/external/uniswap/IPairUniV2.sol";

/**
 * @title Contains functionality to get pricing from protocols that use UniV2 based pool contracts
 */
abstract contract BaseValueProviderUniV2LP is BaseValueProviderLP {
    constructor(address _ethValueOracle) BaseValueProviderLP(_ethValueOracle) { }

    function _getPriceUniV2Contract(
        address uniV2LpTokenToPrice,
        uint256 reserve0,
        uint256 reserve1
    ) internal view returns (uint256) {
        IPairUniV2 pair = IPairUniV2(uniV2LpTokenToPrice);
        IERC20Metadata token0 = IERC20Metadata(pair.token0());
        IERC20Metadata token1 = IERC20Metadata(pair.token1());

        // Get balances normalized to 18 decimals.
        // slither-disable-start similar-names
        // solhint-disable-next-line max-line-length
        uint256 normalizedBalanceToken0 = TokemakPricingPrecision.checkAndNormalizeDecimals(token0.decimals(), reserve0);
        // solhint-disable-next-line max-line-length
        uint256 normalizedBalanceToken1 = TokemakPricingPrecision.checkAndNormalizeDecimals(token1.decimals(), reserve1);
        // slither-disable-end similar-names

        // Get each token's total value in the pool.
        // slither-disable-start similar-names
        uint256 token0PoolValueEth = ethValueOracle.getPrice(
            address(token0), TokemakPricingPrecision.STANDARD_PRECISION, true
        ) * normalizedBalanceToken0;
        uint256 token1PoolValueEth = ethValueOracle.getPrice(
            address(token1), TokemakPricingPrecision.STANDARD_PRECISION, true
        ) * normalizedBalanceToken1;
        // slither-disable-end similar-names

        return _getPriceLp(token0PoolValueEth + token1PoolValueEth, IERC20Metadata(uniV2LpTokenToPrice));
    }
}
