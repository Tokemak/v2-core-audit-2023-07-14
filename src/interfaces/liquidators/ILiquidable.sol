// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

struct SwapperParams {
    address swapperAddress;
    address sellTokenAddress;
    uint256 sellAmount;
    address buyTokenAddress;
    uint256 buyAmount;
    bytes data;
}

interface ILiquidable {
    function liquidate(SwapperParams memory swapperParams) external;
}
