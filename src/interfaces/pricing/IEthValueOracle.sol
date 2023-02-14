// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { BaseValueProvider } from "../../pricing/value-providers/base/BaseValueProvider.sol";

interface IEthValueOracle {
    /**
     * @notice Emitted when value provider is added or removed.
     * @param token Address of token to be mapped with valueProvider.
     * @param valueProviderAddress Address for value provider.
     */
    event ValueProviderUpdated(address token, address valueProviderAddress);

    /**
     * @notice Revert when zero amount.
     */
    error CannotBeZeroAmount();

    /**
     * @notice Returns value provider for token address.
     * @param token Address of token paired with value provider.
     */
    function valueProviderByToken(address token) external view returns (BaseValueProvider);

    /**
     * @notice Allows privileged address to add value providers.
     * @dev Privileged access function.
     * @dev `valueProvider` can be zero address to reset token's value provider.
     * @param token Address of token.
     * @param valueProvider Address of value provider.
     */
    function updateValueProvider(address token, address valueProvider) external;

    /**
     * @notice Returns the price for an amount of token.
     * @dev This function assumes that input values are in the precision of the input token, ie usdc is input
     *      with 6 decimals of precision, the amount returned by its `decimals()` function.  Failure to adhere
     *      to this will result in values that are off by orders of magnitude.
     * @dev priceForValueProvider should always be false for external calls, true for calls from value provider
     *      contracts.
     * @dev Denominations (USD, EUR, etc) aside from Eth should not be priced through this function, as they have
     *      placeholder addresses and do not adhere to ERC20 standards.
     * @param tokenToPrice Address of token to get price of.
     * @param amount Amount of token that is being priced.
     * @param priceForValueProvider Whether or not value provider is the caller.  Determines whether price
     *      returned is in 18 decimals of precision or precision input via `amount` parameter.  Precision
     *      input via `getPrice()` call needed for value provider calls to `EthValueOracle`.
     * @return price Price in eth of amount of tokenToPrice.  Precision varies on return value dependent on
     *      `priceForValueProvider` boolean.
     */
    function getPrice(
        address tokenToPrice,
        uint256 amount,
        bool priceForValueProvider
    ) external view returns (uint256 price);
}
