// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { TokemakPricingPrecision } from "src/pricing/library/TokemakPricingPrecision.sol";

/**
 * @title Eth pricing contract.
 * @dev This contract can be used for any token that is assumed to be 1:1 with Eth (ex: Eth), as well
 *      as for Eth. This contract returns a value of `1` in 1e18 precision, as Eth is the quote token for
 *      the entire system.
 */
contract EthValueProvider is BaseValueProvider {
    constructor(address _ethValueOracle) BaseValueProvider(_ethValueOracle) { }

    function getPrice(address) external view override onlyValueOracle returns (uint256) {
        return TokemakPricingPrecision.STANDARD_PRECISION;
    }
}
