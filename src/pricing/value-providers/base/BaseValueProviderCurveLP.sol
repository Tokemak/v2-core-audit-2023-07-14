// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProviderLP, TokemakPricingPrecision } from "./BaseValueProviderLP.sol";
import { ICurveAddressProvider } from "../../../interfaces/external/curve/ICurveAddressProvider.sol";
import { ICurveFactoryV2 } from "../../../interfaces/external/curve/ICurveFactoryV2.sol";
import { ICurveFactory } from "../../../interfaces/external/curve/ICurveFactory.sol";
import { ICurveMetaPoolFactory } from "../../../interfaces/external/curve/ICurveMetaPoolFactory.sol";

// solhint-disable func-name-mixedcase

/**
 * @title Contains base functionality for Curve LP pricing contracts.
 */
abstract contract BaseValueProviderCurveLP is BaseValueProviderLP {
    /**
     * @notice Returns address of Curve address provider, which holds addresses of various registries. See here for more
     *      information on the Curve address provider: https://curve.readthedocs.io/registry-address-provider.html
     * @dev Address will not change.
     */
    ICurveAddressProvider public constant CURVE_ADDRESS_PROVIDER =
        ICurveAddressProvider(0x0000000022D53366457F9d5E68Ec105046FC4383);

    // Factory addresses will not change, but could be added.
    ICurveFactoryV2 public constant CURVE_V2_FACTORY = ICurveFactoryV2(0xF18056Bbd320E96A48e3Fbf8bC061322531aac99);
    ICurveFactory public constant STABLE_AND_META_FACTORY = ICurveFactory(0xB9fC157394Af804a3578134A6585C0dc9cc990d4);
    ICurveMetaPoolFactory public constant CURVE_METAPOOL_FACTORY =
        ICurveMetaPoolFactory(0x0959158b6040D32d04c301A72CBFD6b39E21c9AE);

    /**
     * @notice Thrown when pool is not registered.
     * @param pool Address of pool that is not registered.
     */
    error CurvePoolNotRegistered(address pool);

    constructor(address _ethValueOracle) BaseValueProviderLP(_ethValueOracle) { }

    function _getCurvePoolValueEth(
        address[] memory tokens,
        uint256[] memory balances
    ) internal view returns (uint256 poolValueEth) {
        for (uint256 i = 0; i < tokens.length; ++i) {
            address currentToken = tokens[i];
            if (currentToken == address(0)) break;
            uint256 normalizedBalance = TokemakPricingPrecision.checkAndNormalizeDecimals(
                TokemakPricingPrecision.getDecimals(currentToken), balances[i]
            );
            poolValueEth += ethValueOracle.getPrice(currentToken, TokemakPricingPrecision.STANDARD_PRECISION, true)
                * normalizedBalance;
        }
    }

    /**
     * Helper functions for various static arrays returned by Curve registries and factories.
     */

    function _getDynamicArray(address[2] memory twoMemberStaticAddressArray) internal pure returns (address[] memory) {
        address[] memory dynamicArray = new address[](2);

        for (uint256 i = 0; i < 2; ++i) {
            dynamicArray[i] = twoMemberStaticAddressArray[i];
        }
        return dynamicArray;
    }

    function _getDynamicArray(address[4] memory fourMemberStaticAddressArray)
        internal
        pure
        returns (address[] memory dynamicAddressArray)
    {
        address[] memory dynamicArray = new address[](4);

        for (uint256 i = 0; i < 4; ++i) {
            address currentAddress = fourMemberStaticAddressArray[i];
            // No need to set zero address
            if (currentAddress == address(0)) break;
            dynamicArray[i] = currentAddress;
        }
        return dynamicArray;
    }

    function _getDynamicArray(address[8] memory eightMemberStaticAddressArray)
        internal
        pure
        returns (address[] memory)
    {
        address[] memory dynamicArray = new address[](8);

        for (uint256 i = 0; i < 8; ++i) {
            address currentAddress = eightMemberStaticAddressArray[i];
            if (currentAddress == address(0)) break;
            dynamicArray[i] = currentAddress;
        }
        return dynamicArray;
    }

    function _getDynamicArray(uint256[2] memory twoMemberStaticUintArray)
        internal
        pure
        returns (uint256[] memory dynamicUintArray)
    {
        uint256[] memory dynamicArray = new uint256[](2);

        for (uint256 i = 0; i < 2; ++i) {
            dynamicArray[i] = twoMemberStaticUintArray[i];
        }
        return dynamicArray;
    }

    function _getDynamicArray(uint256[4] memory fourMemberStaticUintArray)
        internal
        pure
        returns (uint256[] memory dynamicUintArray)
    {
        uint256[] memory dynamicArray = new uint256[](4);

        for (uint256 i = 0; i < 4; ++i) {
            uint256 currentBalance = fourMemberStaticUintArray[i];
            if (currentBalance == 0) break;
            dynamicArray[i] = currentBalance;
        }
        return dynamicArray;
    }

    function _getDynamicArray(uint256[8] memory eightMemberStaticUintArray) internal pure returns (uint256[] memory) {
        uint256[] memory dynamicArray = new uint256[](8);

        for (uint256 i = 0; i < 8; ++i) {
            dynamicArray[i] = eightMemberStaticUintArray[i];
        }
        return dynamicArray;
    }
}
