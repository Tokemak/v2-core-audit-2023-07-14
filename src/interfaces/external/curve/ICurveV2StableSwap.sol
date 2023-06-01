// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ICurveV2StableSwap {
    function coins(uint256 i) external view returns (address);

    function exchange(
        uint256 sellTokenIndex,
        uint256 buyTokenIndex,
        uint256 sellAmount,
        uint256 minBuyAmount
    ) external payable returns (uint256);
}
