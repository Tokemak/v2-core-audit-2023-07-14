// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISyncSwapper } from "./ISyncSwapper.sol";

interface ISwapRouter {
    struct SwapData {
        address token;
        address pool;
        ISyncSwapper swapper;
        bytes data;
    }

    error MaxSlippageExceeded();
    error SwapRouteLookupFailed();

    event SwapRouteSet(address indexed token, SwapData[] routes);
    event SwapForQuoteSuccessful(
        address indexed assetToken,
        uint256 sellAmount,
        address indexed quoteToken,
        uint256 minBuyAmount,
        uint256 buyAmount
    );

    /**
     * @notice Sets a new swap route for a given asset token.
     * @param assetToken The asset token for which the swap route is being set.
     * @param _swapRoute The new swap route as an array of SwapData. The last element represents the quoteToken.
     * @dev Each 'hop' in the swap route is validated using the respective swapper's validate function. The validate
     * function ensures that the encoded data contains the correct 'from' and 'to' addresses.
     */
    function setSwapRoute(address assetToken, SwapData[] calldata _swapRoute) external;

    /**
     * @dev Swaps the asset token for the quote token.
     * @param assetToken The address of the asset token to swap.
     * @param sellAmount The exact amount of the asset token to swap.
     * @param quoteToken The address of the quote token.
     * @param minBuyAmount The minimum amount of the quote token expected to be received from the swap.
     * @return The amount received from the swap.
     */
    function swapForQuote(
        address assetToken,
        uint256 sellAmount,
        address quoteToken,
        uint256 minBuyAmount
    ) external returns (uint256);
}
