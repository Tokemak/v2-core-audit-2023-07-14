// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IstEth {
    function submit(address _referral) external payable returns (uint256);

    function decimals() external view returns (uint8);
}
