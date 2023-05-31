// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";

interface ISyncSwapper {
    error DataMismatch(string element);

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

    /**
     * @notice Validates that the swapData contains the correct information, comparing it with the given 'from' and 'to'
     * addresses
     * @dev This function should revert with a DataMismatch error if the swapData is invalid
     * @param fromAddress The address from which the swap originates
     * @param toAddress The address to which the swap is directed
     * @param swapData The data associated with the swap that needs to be validated
     */
    function validate(address fromAddress, address toAddress, ISwapRouter.SwapData memory swapData) external view;
}
