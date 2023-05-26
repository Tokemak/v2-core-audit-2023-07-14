// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";

interface ISyncSwapper {
    error DataMismatch();

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
     * @notice Validates the swapData
     * @dev This function should revert with DataMismatch if the swapData is invalid
     * @param swapData The swapData to validate
     */
    function validate(ISwapRouter.SwapData memory swapData) external view;
}
