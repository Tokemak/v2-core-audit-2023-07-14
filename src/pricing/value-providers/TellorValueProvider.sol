// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    BaseValueProviderDenominations,
    Denominations
} from "src/pricing/value-providers/base/BaseValueProviderDenominations.sol";
import { IEthValueOracle } from "src/interfaces/pricing/IEthValueOracle.sol";
import { Errors } from "src/utils/Errors.sol";

import { UsingTellor } from "usingtellor/UsingTellor.sol";

/**
 * @title Gets the spot price of tokens that Tellor provides a feed for.
 * @dev Will convert all tokens to Eth pricing regardless of original denomination.
 * @dev Returns 18 decimals of precision.
 */
contract TellorValueProvider is BaseValueProviderDenominations, UsingTellor {
    /**
     * @dev Token addresses to queryIds.  Tellor queryIds can be constructed here:
     *      https://tellor.io/queryidstation/
     */
    mapping(address => bytes32) private tokenQueryIds;

    /// @notice Emitted when a query Id is set or removed.
    event QueryIdSet(address token, bytes32 _queryId);

    event QueryIdRemoved(address token, bytes32 queryId);

    /// @notice Revert used when a query Id is not set and bytes(0) is returned from `tokenQueryIds` mapping.
    error QueryIdNotSet();

    // Tellor requires payable address
    constructor(
        address _tellorOracleAddress,
        address _ethValueOracle
    ) UsingTellor(payable(_tellorOracleAddress)) BaseValueProviderDenominations(_ethValueOracle) {
        Errors.verifyNotZero(_tellorOracleAddress, "tellor");
    }

    /**
     * @notice Allows permissioned address to set _queryId.
     * @param token Address of token to set queryId for.
     * @param _queryId Bytes32 queryId.
     */
    function addQueryId(address token, bytes32 _queryId) external onlyOwner {
        Errors.verifyNotZero(token, "tokenForQueryId");
        if (_queryId == bytes32(0)) revert Errors.MustBeSet();
        if (tokenQueryIds[token] != bytes32(0)) revert Errors.MustBeZero();
        tokenQueryIds[token] = _queryId;
        emit QueryIdSet(token, _queryId);
    }

    /**
     * @notice Allows permissioned removal of queryId.
     * @param token Token to set queryId for.
     */
    function removeQueryId(address token) external onlyOwner {
        Errors.verifyNotZero(token, "tokenToRemoveQueryId");
        bytes32 queryIdBeforeDeletion = tokenQueryIds[token];
        if (queryIdBeforeDeletion == bytes32(0)) revert Errors.MustBeSet();
        delete tokenQueryIds[token];
        emit QueryIdRemoved(token, queryIdBeforeDeletion);
    }

    /**
     * @notice External function to view queryId for token address.
     * @dev Can return bytes32(0).
     * @param token Address of token to view queryId for.
     */
    function getQueryId(address token) external view returns (bytes32) {
        return tokenQueryIds[token];
    }

    /**
     * @dev Tellor always returns prices with 18 decimals of precision for spot pricing, so we do not need
     *      to worry about increasing or decreasing precision here.  See here:
     *      https://github.com/tellor-io/dataSpecs/blob/main/types/SpotPrice.md
     */
    // slither-disable-start timestamp
    function getPrice(address tokenToPrice) external view override onlyValueOracle returns (uint256) {
        address denomination = _getDenomination(tokenToPrice);
        uint256 timestamp = block.timestamp;
        // Giving time for Tellor network to dispute price
        (bytes memory value, uint256 timestampRetrieved) =
            getDataBefore(_getQueryId(tokenToPrice), timestamp - 30 minutes);

        // Check that something was returned and freshness of price.
        if (timestampRetrieved == 0 || timestamp - timestampRetrieved > DENOMINATION_TIMEOUT) {
            revert InvalidDataReturned();
        }

        uint256 price = abi.decode(value, (uint256));

        /**
         * Eth denominations are what we want, do not need to be repriced.
         *
         * If the token is `Denominations.ETH_IN_USD` and this check is not present
         *   an infinite loop will occur with `_getPriceDenominationUSD()`.  This is
         *   due to the fact that `Denominations.ETH_IN_USD` has its denomination set
         *   `Denominations.USD` in the system. This is the one token that we want returned
         *   with its denomination in USD as it has a special use case, converting assets
         *   priced in USD to Eth.
         */
        if (denomination != Denominations.ETH && tokenToPrice != Denominations.ETH_IN_USD) {
            if (denomination == Denominations.USD) {
                price == _getPriceDenominationUSD(price);
            } else {
                price = _getPriceDenomination(denomination, price);
            }
        }
        return price;
    }
    // slither-disable-end timestamp

    /// @dev Used to enforce non-existent queryId checks
    function _getQueryId(address token) private view returns (bytes32 queryId) {
        queryId = tokenQueryIds[token];
        if (queryId == bytes32(0)) revert QueryIdNotSet();
    }
}
