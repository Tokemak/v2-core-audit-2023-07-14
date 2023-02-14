// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProvider } from "./BaseValueProvider.sol";
import { TokemakPricingPrecision } from "../../library/TokemakPricingPrecision.sol";

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title Base contract for value provider contracts handling the pricing of LP tokens.
 */
abstract contract BaseValueProviderLP is BaseValueProvider {
    constructor(address _ethValueOracle) BaseValueProvider(_ethValueOracle) { }

    function _getPriceLp(uint256 poolValueEth, IERC20Metadata tokenToPrice) internal view returns (uint256) {
        // Normalize decimals for total supply of tokens.
        uint256 normalizedTotalSupply =
            TokemakPricingPrecision.checkAndNormalizeDecimals(tokenToPrice.decimals(), tokenToPrice.totalSupply());

        // Division takes care of excess precision in `poolValueEth`
        return poolValueEth / normalizedTotalSupply;
    }
}
