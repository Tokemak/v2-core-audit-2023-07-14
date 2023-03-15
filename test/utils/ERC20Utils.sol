// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

library ERC20Utils {
    function transferAll(IERC20 token, address from, address to) internal {
        uint256 balance = token.balanceOf(from);
        token.transfer(to, balance);
    }
}
