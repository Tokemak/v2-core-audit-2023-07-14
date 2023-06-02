// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

library LibAdapter {
    using SafeERC20 for IERC20;

    // Utils
    function _approve(IERC20 token, address spender, uint256 amount) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance == 0) {
            token.approve(spender, amount);
        }
        if (currentAllowance < amount) {
            token.safeIncreaseAllowance(spender, amount);
        }
        if (currentAllowance > amount) token.safeDecreaseAllowance(spender, currentAllowance);
    }

    function _approve(address token, address spender, uint256 amount) internal {
        _approve(IERC20(token), spender, amount);
    }
}
