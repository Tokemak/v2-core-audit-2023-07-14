// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { TokemakPricingPrecision } from "src/pricing/library/TokemakPricingPrecision.sol";

import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Base contract for value provider contracts handling the pricing of LP tokens.
abstract contract BaseValueProviderLP is BaseValueProvider {
    constructor(address _ethValueOracle) BaseValueProvider(_ethValueOracle) { }

    /// @dev When using this function, `poolValueEth` must be passed in with 1e36 precision.
    function _getPriceLp(uint256 poolValueEth, IERC20Metadata tokenToPrice) internal view returns (uint256) {
        // Normalize decimals for total supply of tokens.
        uint8 tokenDecimals = tokenToPrice.decimals();
        uint256 tokenTotalSupply = tokenToPrice.totalSupply();
        uint256 normalizedTotalSupply =
            TokemakPricingPrecision.checkAndNormalizeDecimals(tokenDecimals, tokenTotalSupply);

        // Division takes care of excess precision in `poolValueEth`
        return poolValueEth / normalizedTotalSupply;
    }
}
