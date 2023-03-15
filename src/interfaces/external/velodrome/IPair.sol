// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPair {
    function tokens() external view returns (address, address);
    function transfer(address dst, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
