// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISyncSwapper {
    error TokenAddressZero();

    /**
     * @notice Swaps sellToken for buyToken
     * @param pool The address of the pool for the swapper
     * @param sellTokenAddress The address of the token to sell
     * @param sellAmount The amount of sellToken to sell
     * @param buyTokenAddress The address of the token to buy
     * @param minBuyAmount The minimum amount of buyToken expected
     * @param data Additional data used differently by the different swappers
     * @return actualBuyAmount The actual amount received from the swap
     */
    function swap(
        address pool,
        address sellTokenAddress,
        uint256 sellAmount,
        address buyTokenAddress,
        uint256 minBuyAmount,
        bytes memory data
    ) external returns (uint256 actualBuyAmount);
}
