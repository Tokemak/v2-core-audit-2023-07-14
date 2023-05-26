// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IBasePool is IERC20 {
    function getPoolId() external view returns (bytes32);
}
