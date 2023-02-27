// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

library LibAdapter {
    using SafeERC20 for IERC20;

    // Utils
    function _approve(IERC20 token, address spender, uint256 amount) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance > 0) {
            token.safeDecreaseAllowance(spender, currentAllowance);
        }
        token.safeIncreaseAllowance(spender, amount);
    }

    function _validateAndApprove(address coin, address spender, uint256 amount) internal {
        // _validateToken(coin); TODO: Call to Token Registry
        IERC20 coinErc = IERC20(coin);
        if (coinErc.balanceOf(address(this)) < amount) revert("Insufficient balance");
        _approve(coinErc, spender, amount);
    }

    function _toDynamicArray(uint256 value) internal pure returns (uint256[] memory dynamicArray) {
        dynamicArray = new uint256[](1);
        dynamicArray[0] = value;
    }

    function _toDynamicArray(address value) internal pure returns (address[] memory dynamicArray) {
        dynamicArray = new address[](1);
        dynamicArray[0] = value;
    }
}
