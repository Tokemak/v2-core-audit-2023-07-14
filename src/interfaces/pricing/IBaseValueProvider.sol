// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IBaseValueProvider {
    /**
     * @notice gets price
     * @param pricingAddress Address of token or pool that needs pricing.
     */
    function getPrice(address pricingAddress) external;
}
