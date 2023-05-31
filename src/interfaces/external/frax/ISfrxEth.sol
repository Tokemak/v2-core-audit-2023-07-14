// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISfrxEth {
    /// @notice Returns price of sfrxEth in frxEth.
    function pricePerShare() external view returns (uint256);

    /// @notice Represents frxETH
    function asset() external view returns (address);
}
