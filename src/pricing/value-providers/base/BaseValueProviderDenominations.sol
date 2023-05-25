// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { TokemakPricingPrecision } from "src/pricing/library/TokemakPricingPrecision.sol";
import { Denominations } from "src/pricing/library/Denominations.sol";
import { Errors } from "src/utils/Errors.sol";

/// @title Base contract for `ValueProvider.sol` contracts that require token denominations.
abstract contract BaseValueProviderDenominations is BaseValueProvider {
    /// @notice Used to denote what denomination a token is in.
    enum Denomination {
        ETH,
        USD
    }

    /// @notice Amount of time that can pass until a price is considered stale.
    uint256 public constant DENOMINATION_TIMEOUT = 24 hours;

    // Thrown in the event that parameter returned with data is invalid.  Timestamp, pricing, etc.
    error InvalidDataReturned();

    constructor(address _ethValueOracle) BaseValueProvider(_ethValueOracle) { }

    // Handles non-Eth denomination if neccessary.
    function _denominationPricing(
        Denomination denomination,
        uint256 normalizedPrice,
        address tokenToPrice
    ) internal view returns (uint256) {
        if (tokenToPrice != Denominations.ETH_IN_USD && denomination == Denomination.USD) {
            return _getPriceDenominationUSD(normalizedPrice);
        }
        return normalizedPrice;
    }

    /**
     * @notice Necessary due to lack of USD / Eth price feed.  Price of both assets in USD make it possible
     *      to get `normalizedPrice` in terms of Eth.  Many assets are priced in USD as opposed to crypto assets
     *      on Chainlink price feeds.
     *
     * @param normalizedPrice  Normalized price of asset in USD
     */
    function _getPriceDenominationUSD(uint256 normalizedPrice) private view returns (uint256) {
        uint256 ethInUsd =
            ethValueOracle.getPrice(Denominations.ETH_IN_USD, TokemakPricingPrecision.STANDARD_PRECISION, true);

        return (TokemakPricingPrecision.increasePrecision(normalizedPrice) / ethInUsd);
    }
}
