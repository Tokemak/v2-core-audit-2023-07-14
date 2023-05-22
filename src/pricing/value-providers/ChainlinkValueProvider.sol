// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    BaseValueProviderDenominations,
    TokemakPricingPrecision,
    Denominations
} from "src/pricing/value-providers/base/BaseValueProviderDenominations.sol";
import { IAggregatorV3Interface } from "src/interfaces/external/chainlink/IAggregatorV3Interface.sol";
import { Errors } from "src/utils/Errors.sol";

/**
 * @title Gets the value of tokens that Chainlink provides a feed for.
 * @dev Will convert all tokens to Eth pricing regardless of original denomination.
 */
contract ChainlinkValueProvider is BaseValueProviderDenominations {
    /// @dev Mapping of token to oracle interface.  Private to enforce zero address checks.
    mapping(address => IAggregatorV3Interface) private tokenToChainlinkOracle;

    /**
     * @notice Emitted when a token has an oracle address set.
     * @param token Address of token.
     * @param chainlinkOracle Address of chainlink oracle contract. Will be zero address on removal.
     */
    event ChainlinkOracleSet(address token, address chainlinkOracle);

    /**
     * @notice Emitted when Oracle removed from token.
     * @param token Address of token.
     * @param chainlinkOracle Address of oracle.
     */
    event ChainlinkOracleRemoved(address token, address chainlinkOracle);

    constructor(address _ethValueOracle) BaseValueProviderDenominations(_ethValueOracle) { }

    /**
     * @notice Allows oracle address to be set for token.
     * @dev Only owner of contract system can access.
     * @param token Address of token for which oracle will be set.
     * @param chainlinkOracle Address of oracle to be set.
     */
    function addChainlinkOracle(address token, address chainlinkOracle) external onlyOwner {
        Errors.verifyNotZero(token, "tokenToAddOracle");
        Errors.verifyNotZero(chainlinkOracle, "oracle");
        if (address(tokenToChainlinkOracle[token]) != address(0)) revert Errors.MustBeZero();
        tokenToChainlinkOracle[token] = IAggregatorV3Interface(chainlinkOracle);
        emit ChainlinkOracleSet(token, chainlinkOracle);
    }

    function removeChainlinkOracle(address token) external onlyOwner {
        Errors.verifyNotZero(token, "tokenToRemoveOracle");
        address oracleBeforeDeletion = address(tokenToChainlinkOracle[token]);
        if (oracleBeforeDeletion == address(0)) revert Errors.MustBeSet();
        delete tokenToChainlinkOracle[token];
        emit ChainlinkOracleRemoved(token, oracleBeforeDeletion);
    }

    /// @dev Returns address(0) when token does not have a set oracle.
    function getChainlinkOracle(address token) external view returns (IAggregatorV3Interface) {
        return tokenToChainlinkOracle[token];
    }

    // slither-disable-start timestamp
    function getPrice(address token) external view override onlyValueOracle returns (uint256) {
        address denomination = _getDenomination(token);
        IAggregatorV3Interface chainlinkOracle = _getChainlinkOracle(token);
        (uint80 roundId, int256 price,, uint256 updatedAt,) = chainlinkOracle.latestRoundData();
        uint256 timestamp = block.timestamp;
        if (
            roundId == 0 || price <= 0 || updatedAt == 0 || updatedAt > timestamp
                || updatedAt < timestamp - DENOMINATION_TIMEOUT
        ) revert InvalidDataReturned();

        // Chainlink feeds have certain decimal precisions, does not neccessarily conform to underlying asset.
        uint256 decimals = chainlinkOracle.decimals();
        uint256 normalizedPrice = TokemakPricingPrecision.checkAndNormalizeDecimals(decimals, uint256(price));

        /**
         * Eth denominations are what we want, do not need to be repriced.
         *
         * If the token is `Denominations.ETH_IN_USD` and the Denominations.ETH_IN_USD check
         *   is not present an infinite loop will occur with `_getPriceDenominationUSD()`.
         *   This is due to the fact that `Denominations.ETH_IN_USD` has its denomination set
         *   `Denominations.USD` in the system. This is the one token that we want returned
         *   with its denomination in USD as it has a special use case, converting assets
         *   priced in USD to Eth.
         */
        if (denomination != Denominations.ETH && token != Denominations.ETH_IN_USD) {
            if (denomination == Denominations.USD) {
                // USD special case, need to get Eth price in USD to convert to Eth.
                normalizedPrice = _getPriceDenominationUSD(normalizedPrice);
            } else {
                normalizedPrice = _getPriceDenomination(denomination, normalizedPrice);
            }
        }
        return normalizedPrice;
    }
    // slither-disable-end timestamp

    /// @dev internal getter to access `tokenToChainlinkOracle` mapping, enforces address(0) check.
    function _getChainlinkOracle(address token) internal view returns (IAggregatorV3Interface chainlinkOracle) {
        chainlinkOracle = tokenToChainlinkOracle[token];
        Errors.verifyNotZero(address(chainlinkOracle), "chainlinkOracle");
    }
}
