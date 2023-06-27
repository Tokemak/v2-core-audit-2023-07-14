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
    /**
     * @notice Used to store info on token's Chainlink feed.
     * @param oracle Address of Chainlink oracle for token mapped.
     * @param denomination Enum representing what token mapped is denominated in.
     * @param decimals Number of decimal precision that oracle returns.
     */
    struct ChainlinkInfo {
        IAggregatorV3Interface oracle;
        Denomination denomination;
        uint8 decimals;
    }

    /// @dev Mapping of token to ChainlinkInfo struct.  Private to enforce zero address checks.
    mapping(address => ChainlinkInfo) private chainlinkOracleInfo;

    /**
     * @notice Emitted when a token has an oracle address set.
     * @param token Address of token.
     * @param chainlinkOracle Address of chainlink oracle contract.
     * @param denomination Enum representing denomination.
     * @param decimals Number of decimals precision that oracle returns.
     */
    event ChainlinkRegistrationAdded(address token, address chainlinkOracle, Denomination denomination, uint8 decimals);

    /**
     * @notice Emitted when Oracle removed from token.
     * @param token Address of token.
     * @param chainlinkOracle Address of oracle.
     */
    event ChainlinkRegistrationRemoved(address token, address chainlinkOracle);

    constructor(address _ethValueOracle) BaseValueProviderDenominations(_ethValueOracle) { }

    /**
     * @notice Allows oracle address and denominations to be set for token.
     * @param token Address of token for which oracle will be set.
     * @param chainlinkOracle Address of oracle to be set.
     * @param denomination Address of denomination to be set.
     */
    function registerChainlinkOracle(
        address token,
        IAggregatorV3Interface chainlinkOracle,
        Denomination denomination
    ) external onlyOwner {
        Errors.verifyNotZero(token, "tokenToAddOracle");
        Errors.verifyNotZero(address(chainlinkOracle), "oracle");
        if (address(chainlinkOracleInfo[token].oracle) != address(0)) revert Errors.MustBeZero();

        uint8 oracleDecimals = chainlinkOracle.decimals();
        chainlinkOracleInfo[token] =
            ChainlinkInfo({ oracle: chainlinkOracle, denomination: denomination, decimals: oracleDecimals });
        emit ChainlinkRegistrationAdded(token, address(chainlinkOracle), denomination, oracleDecimals);
    }

    /**
     * @notice Allows oracle address and denominations to be removed.
     * @param token Address of token to remove registration for.
     */
    function removeChainlinkRegistration(address token) external onlyOwner {
        Errors.verifyNotZero(token, "tokenToRemoveOracle");
        address oracleBeforeDeletion = address(chainlinkOracleInfo[token].oracle);
        if (oracleBeforeDeletion == address(0)) revert Errors.MustBeSet();
        delete chainlinkOracleInfo[token];
        emit ChainlinkRegistrationRemoved(token, oracleBeforeDeletion);
    }

    function getChainlinkInfo(address token) external view returns (ChainlinkInfo memory) {
        return chainlinkOracleInfo[token];
    }

    // slither-disable-start timestamp
    function getPrice(address token) external view override onlyValueOracle returns (uint256) {
        ChainlinkInfo memory chainlinkOracle = _getChainlinkInfo(token);

        // Partial return values are intentionally ignored. This call provides the most efficient way to obtain the
        // data.
        // slither-disable-next-line unused-return
        (uint80 roundId, int256 price,, uint256 updatedAt,) = chainlinkOracle.oracle.latestRoundData();
        uint256 timestamp = block.timestamp;
        if (
            roundId == 0 || price <= 0 || updatedAt == 0 || updatedAt > timestamp
                || updatedAt < timestamp - DENOMINATION_TIMEOUT
        ) revert InvalidDataReturned();

        // Chainlink feeds have certain decimal precisions, does not neccessarily conform to underlying asset.
        uint256 normalizedPrice =
            TokemakPricingPrecision.checkAndNormalizeDecimals(chainlinkOracle.decimals, uint256(price));

        return _denominationPricing(chainlinkOracle.denomination, normalizedPrice, token);
    }
    // slither-disable-end timestamp

    /// @dev internal getter to access `tokenToChainlinkOracle` mapping, enforces address(0) check.
    function _getChainlinkInfo(address token) internal view returns (ChainlinkInfo memory chainlinkInfo) {
        chainlinkInfo = chainlinkOracleInfo[token];
        Errors.verifyNotZero(address(chainlinkInfo.oracle), "chainlinkOracle");
    }
}
