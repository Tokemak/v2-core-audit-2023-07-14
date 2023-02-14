// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IEthValueOracle } from "../interfaces/pricing/IEthValueOracle.sol";
import { BaseValueProvider } from "./value-providers/base/BaseValueProvider.sol";
import { TokemakPricingPrecision } from "./library/TokemakPricingPrecision.sol";

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";

/**
 * @title Pricing and registry contract for Tokemak pricing system.
 * @notice Holds all token => ValueProvider.sol combinations.  Also allows for retrieving price from ValueProvider.sol
 *      contracts.
 */
contract EthValueOracle is IEthValueOracle, Ownable {
    mapping(address => BaseValueProvider) public override valueProviderByToken;

    function updateValueProvider(address token, address valueProvider) external onlyOwner {
        if (token == address(0)) revert BaseValueProvider.CannotBeZeroAddress();
        valueProviderByToken[token] = BaseValueProvider(valueProvider);
        emit ValueProviderUpdated(token, valueProvider);
    }

    // slither-disable-start boolean-equal
    function getPrice(
        address tokenToPrice,
        uint256 amount,
        bool priceForValueProvider
    ) external view returns (uint256) {
        if (amount == 0) revert CannotBeZeroAmount();
        BaseValueProvider valueProvider = valueProviderByToken[tokenToPrice];
        if (address(valueProvider) == address(0)) revert BaseValueProvider.CannotBeZeroAddress();

        if (priceForValueProvider == true) {
            return TokemakPricingPrecision.removePrecision(valueProvider.getPrice(tokenToPrice) * amount);
        }
        // slither-disable-end boolean-equal

        /**
         * `checkandNormalizeDecimals` used to normalize amount input to 18 decimals if needed.
         * `removePrecision` takes away extra 18 decimals of precision that multiplying price returned
         *    from value provider and normalized input price gives.
         */
        return TokemakPricingPrecision.removePrecision(
            valueProvider.getPrice(tokenToPrice)
                * TokemakPricingPrecision.checkAndNormalizeDecimals(
                    TokemakPricingPrecision.getDecimals(tokenToPrice), amount
                )
        );
    }
}
