// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IEthValueOracle } from "src/interfaces/pricing/IEthValueOracle.sol";
import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { TokemakPricingPrecision } from "src/pricing/library/TokemakPricingPrecision.sol";
import { Errors } from "src/utils/Errors.sol";

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";

/**
 * @title Pricing and registry contract for Tokemak pricing system.
 * @notice Holds all token => ValueProvider.sol combinations.  Also allows for retrieving price from ValueProvider.sol
 *      contracts.
 */
contract EthValueOracle is IEthValueOracle, Ownable {
    mapping(address => BaseValueProvider) public override valueProviderByToken;

    function addValueProvider(address token, address valueProvider) external onlyOwner {
        Errors.verifyNotZero(token, "tokenToPrice");
        Errors.verifyNotZero(valueProvider, "valueProvider");
        if (address(valueProviderByToken[token]) != address(0)) revert Errors.MustBeZero();
        valueProviderByToken[token] = BaseValueProvider(valueProvider);
        emit ValueProviderAdded(token, valueProvider);
    }

    function removeValueProvider(address token) external onlyOwner {
        Errors.verifyNotZero(token, "tokenToPrice");
        address valueProviderBeforeDeletion = address(valueProviderByToken[token]);
        if (valueProviderBeforeDeletion == address(0)) revert Errors.MustBeSet();
        delete valueProviderByToken[token];
        emit ValueProviderRemoved(token, valueProviderBeforeDeletion);
    }

    // slither-disable-start boolean-equal
    function getPrice(
        address tokenToPrice,
        uint256 amount,
        bool priceForValueProvider
    ) external view returns (uint256) {
        if (amount == 0) revert CannotBeZeroAmount();
        BaseValueProvider valueProvider = valueProviderByToken[tokenToPrice];
        Errors.verifyNotZero(address(valueProvider), "valueProvider");

        if (priceForValueProvider == true) {
            return TokemakPricingPrecision.removePrecision(valueProvider.getPrice(tokenToPrice) * amount);
        }

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
    // slither-disable-end boolean-equal
}
