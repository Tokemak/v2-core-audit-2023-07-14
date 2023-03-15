// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IStakingRewards {
    function rewardsToken() external view returns (IERC20);
}
