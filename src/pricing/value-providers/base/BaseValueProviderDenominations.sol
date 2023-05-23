// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Multiple denominations will always require pricing calls back into EthOracle.sol.
import { BaseValueProvider } from "src/pricing/value-providers/base/BaseValueProvider.sol";
import { TokemakPricingPrecision } from "src/pricing/library/TokemakPricingPrecision.sol";
import { Denominations } from "src/pricing/library/Denominations.sol";
import { Errors } from "src/utils/Errors.sol";

/// @title Base contract for `ValueProvider.sol` contracts that require token denominations.
abstract contract BaseValueProviderDenominations is BaseValueProvider {
    /// @notice Amount of time that can pass until a price is considered stale.
    // TODO: Figure out what a good timeframe is, figure out how to differentiate stEth (updated every 24 hours).
    uint256 public constant DENOMINATION_TIMEOUT = 24 hours;

    /**
     * @notice Mapping of token addresses to denomination addresses.
     * @dev See https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/Denominations.sol
     *      for non-Ethereum based asset addresses.
     * @dev Private in order to enforce checks on returned address during interactions with inheriting contracts.
     */
    mapping(address => address) private tokenDenomination;

    /**
     * @notice Event emitted when a token denomination is set.
     * @param token Address of token that denomination is being set for.
     * @param denomination Address of denomination.
     */
    event TokenDenominationSet(address token, address denomination);

    /**
     * @notice Emitted when token denomination removed.
     * @param token Address to token for which denomination is being removed.
     * @param denomination Address of denomination.
     */
    event TokenDenominationRemoved(address token, address denomination);

    // Thrown in the event that parameter returned with data is invalid.  Timestamp, pricing, etc.
    error InvalidDataReturned();

    constructor(address _ethValueOracle) BaseValueProvider(_ethValueOracle) { }

    /**
     * @notice Sets asset that token is denominated in.
     * @param token Address of token to set denomination for.
     * @param denomination Address of denomination for token.
     */
    function addDenomination(address token, address denomination) external onlyOwner {
        Errors.verifyNotZero(token, "tokenToDenominate");
        Errors.verifyNotZero(denomination, "denomination");
        if (tokenDenomination[token] != address(0)) revert Errors.MustBeZero();
        tokenDenomination[token] = denomination;
        emit TokenDenominationSet(token, denomination);
    }

    /**
     * @notice Removes denomination from token address.
     * @dev Resets denomination to address(0).
     * @param token Address token to remove denomination from.
     */
    function removeDenomination(address token) external onlyOwner {
        Errors.verifyNotZero(token, "tokenWithDenomination");
        address denominationBeforeDeletion = tokenDenomination[token];
        if (denominationBeforeDeletion == address(0)) revert Errors.MustBeSet();
        delete tokenDenomination[token];
        emit TokenDenominationRemoved(token, denominationBeforeDeletion);
    }

    /**
     * @notice Gets denomination for token.
     * @dev Will return address(0) if denomination does not exist.
     * @param token Address of token to get denomination for.
     */
    function getDenomination(address token) external view returns (address) {
        return tokenDenomination[token];
    }

    function _getPriceDenomination(address denomination, uint256 normalizedPrice) internal view returns (uint256) {
        uint256 denominationPriceInEth =
            ethValueOracle.getPrice(denomination, TokemakPricingPrecision.STANDARD_PRECISION, true);
        /**
         * Precision is increased here to cancel out the precision loss that dividing causes.  This keeps
         * calculations at 18 decimals of precision.
         */
        return TokemakPricingPrecision.increasePrecision(normalizedPrice) / denominationPriceInEth;
    }

    /**
     * @notice Necessary due to lack of USD / Eth price feed.  Price of both assets in USD make it possible
     *      to get `normalizedPrice` in terms of Eth.  Many assets are priced in USD as opposed to crypto assets
     *      on Chainlink price feeds.
     *
     * @param normalizedPrice  Normalized price of asset in USD
     */
    function _getPriceDenominationUSD(uint256 normalizedPrice) internal view returns (uint256) {
        uint256 ethInUsd =
            ethValueOracle.getPrice(Denominations.ETH_IN_USD, TokemakPricingPrecision.STANDARD_PRECISION, true);

        return (TokemakPricingPrecision.increasePrecision(normalizedPrice) / ethInUsd);
    }

    /**
     * @dev Used in conjunction with private mapping to enforce no zero addresses being returned.
     * @param token Address of token to get denomination for.
     */
    function _getDenomination(address token) internal view returns (address) {
        address denomination = tokenDenomination[token];
        Errors.verifyNotZero(denomination, "denomination");
        return denomination;
    }
}
