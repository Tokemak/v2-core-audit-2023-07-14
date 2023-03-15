// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGauge {
    function rewards(uint256 index) external view returns (address);
    function rewardsListLength() external view returns (uint256);
    function getReward(address account, address[] memory tokens) external;
    function claimFees() external returns (uint256 claimed0, uint256 claimed1);
}
