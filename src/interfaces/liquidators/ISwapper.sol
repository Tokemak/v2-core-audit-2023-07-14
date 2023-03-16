// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISwapper {
    error TokenAddressZero();
    error SwapFailed();
    error InsufficientBuyAmountReceived(uint256 buyTokenAmountReceived, uint256 buyAmount);
    error InsufficientSellAmount();
    error InsufficientBuyAmount();
    error InsufficientBalance(uint256 balanceNeeded, uint256 balanceAvailable);

    /**
     * @notice Swaps sellToken for buyToken
     * @param sellTokenAddress The address of the token to sell
     * @param sellAmount The amount of sellToken to sell
     * @param buyTokenAddress The address of the token to buy
     * @param buyAmount The amount of buyToken to buy
     * @param data Payload comming from the aggregator API
     */
    function swap(
        address sellTokenAddress,
        uint256 sellAmount,
        address buyTokenAddress,
        uint256 buyAmount,
        bytes memory data
    ) external;
}
