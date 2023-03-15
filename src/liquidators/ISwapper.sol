// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISwapper {
    error TokenAddressZero();
    error SwapFailed();
    error InsufficientBuyAmountReceived(uint256 buyTokenAmountReceived, uint256 buyAmount);
    error InsufficientSellAmount();
    error InsufficientBuyAmount();
    error InsufficientBalance(uint256 balanceNeeded, uint256 balanceAvailable);

    function swap(
        address sellTokenAddress,
        uint256 sellAmount,
        address buyTokenAddress,
        uint256 buyAmount,
        bytes memory data
    ) external;
}
