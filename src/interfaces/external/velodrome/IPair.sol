// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IPair is IERC20 {
    function tokens() external view returns (address, address);
    function transfer(address dst, uint256 amount) external returns (bool);

    /**
     * @notice Gets reserves of Velodrome pool.
     */
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast);
}
