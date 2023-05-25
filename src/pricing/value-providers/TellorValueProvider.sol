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
     * @notice Used to store information about Tellor price queries.
     * @dev No decimals, all returned in e18 precision.
     * @param queryId bytes32 queryId for pricing query. See here: https://tellor.io/queryidstation/.
     * @param denomination Enum representing denomination of price returned.
     */
    struct TellorInfo {
        bytes32 queryId;
        Denomination denomination;
    }

    /// @dev Token address to TellorInfo structs.
    mapping(address => TellorInfo) private tellorQueryInfo;

    /// @notice Emitted when information about a Tellor query is registered.
    event TellorRegistrationAdded(address token, Denomination denomination, bytes32 _queryId);

    /// @notice Emitted when  information about a Tellor query is removed.
    event TellorRegistrationRemoved(address token, bytes32 queryId);

    // Tellor requires payable address
    constructor(
        address _tellorOracleAddress,
        address _ethValueOracle
    ) UsingTellor(payable(_tellorOracleAddress)) BaseValueProviderDenominations(_ethValueOracle) {
        Errors.verifyNotZero(_tellorOracleAddress, "tellor");
    }

    /**
     * @notice Allows permissioned address to set _queryId, denomination for token address.
     * @param token Address of token to set queryId for.
     * @param _queryId Bytes32 queryId.
     * @param denomination Denomination of token.
     */
    function addTellorRegistration(address token, bytes32 _queryId, Denomination denomination) external onlyOwner {
        Errors.verifyNotZero(token, "tokenForQueryId");
        Errors.verifyNotZero(_queryId, "queryId");
        if (tellorQueryInfo[token].queryId != bytes32(0)) revert Errors.MustBeZero();
        tellorQueryInfo[token] = TellorInfo({ queryId: _queryId, denomination: denomination });
        emit TellorRegistrationAdded(token, denomination, _queryId);
    }

    /**
     * @notice Allows permissioned removal registration for token address.
     * @param token Token to remove TellorInfo struct for.
     */
    function removeTellorRegistration(address token) external onlyOwner {
        Errors.verifyNotZero(token, "tokenToRemoveRegistration");
        bytes32 queryIdBeforeDeletion = tellorQueryInfo[token].queryId;
        Errors.verifyNotZero(queryIdBeforeDeletion, "queryIdBeforeDeletion");
        delete tellorQueryInfo[token];
        emit TellorRegistrationRemoved(token, queryIdBeforeDeletion);
    }

    /**
     * @notice External function to view TellorInfo struct for token address.
     * @param token Address of token to view TellorInfo struct for.
     */
    function getQueryInfo(address token) external view returns (TellorInfo memory) {
        return tellorQueryInfo[token];
    }

    /**
     * @dev Tellor always returns prices with 18 decimals of precision for spot pricing, so we do not need
     *      to worry about increasing or decreasing precision here.  See here:
     *      https://github.com/tellor-io/dataSpecs/blob/main/types/SpotPrice.md
     */
    // slither-disable-start timestamp
    function getPrice(address tokenToPrice) external view override onlyValueOracle returns (uint256) {
        TellorInfo memory tellorInfo = tellorQueryInfo[tokenToPrice];
        uint256 timestamp = block.timestamp;
        // Giving time for Tellor network to dispute price
        (bytes memory value, uint256 timestampRetrieved) = getDataBefore(tellorInfo.queryId, timestamp - 30 minutes);

        // Check that something was returned and freshness of price.
        if (timestampRetrieved == 0 || timestamp - timestampRetrieved > DENOMINATION_TIMEOUT) {
            revert InvalidDataReturned();
        }

        uint256 price = abi.decode(value, (uint256));
        return _denominationPricing(tellorInfo.denomination, price, tokenToPrice);
    }
    // slither-disable-end timestamp

    /// @dev Used to enforce non-existent queryId checks
    function _getQueryInfo(address token) private view returns (TellorInfo memory tellorInfo) {
        tellorInfo = tellorQueryInfo[token];
        Errors.verifyNotZero(tellorInfo.queryId, "queryId");
    }
}
