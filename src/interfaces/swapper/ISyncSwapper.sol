// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISyncSwapper {
    error TokenAddressZero();

    /**
     * @notice Swaps sellToken for buyToken
     * @param sellTokenAddress The address of the token to sell
     * @param sellAmount The amount of sellToken to sell
     * @param buyTokenAddress The address of the token to buy
     * @param minBuyAmount The minimum amount of buyToken expected
     * @return actualBuyAmount The actual amount received from the swap
     */
    function swap(
        address sellTokenAddress,
        uint256 sellAmount,
        address buyTokenAddress,
        uint256 minBuyAmount
    ) external returns (uint256 actualBuyAmount);
}
