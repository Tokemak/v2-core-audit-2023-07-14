// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import { ERC20Utils } from "../libs/ERC20Utils.sol";
import { ISwapper } from "./ISwapper.sol";

contract BaseSwapperAdapter is ISwapper, ReentrancyGuard {
    // slither-disable-start naming-convention
    // solhint-disable-next-line var-name-mixedcase
    address public immutable AGGREGATOR;
    // slither-disable-end naming-convention

    constructor(address aggregator) {
        if (aggregator == address(0)) revert TokenAddressZero();
        AGGREGATOR = aggregator;
    }

    // slither-disable-start calls-loop
    function swap(
        address sellTokenAddress,
        uint256 sellAmount,
        address buyTokenAddress,
        uint256 buyAmount,
        bytes memory data
    ) public nonReentrant {
        if (buyTokenAddress == address(0)) revert TokenAddressZero();
        if (sellTokenAddress == address(0)) revert TokenAddressZero();
        if (sellAmount == 0) revert InsufficientSellAmount();
        if (buyAmount == 0) revert InsufficientBuyAmount();

        IERC20 sellToken = IERC20(sellTokenAddress);
        IERC20 buyToken = IERC20(buyTokenAddress);

        uint256 sellTokenBalance = sellToken.balanceOf(address(this));

        if (sellTokenBalance < sellAmount) {
            revert InsufficientBalance(sellTokenBalance, sellAmount);
        }

        ERC20Utils.approve(sellToken, AGGREGATOR, sellAmount);

        uint256 buyTokenBalanceBefore = buyToken.balanceOf(address(this));

        // slither-disable-start low-level-calls
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = AGGREGATOR.call(data);
        // slither-disable-end low-level-calls

        if (!success) {
            revert SwapFailed();
        }

        uint256 buyTokenBalanceAfter = buyToken.balanceOf(address(this));
        uint256 buyTokenAmountReceived = buyTokenBalanceAfter - buyTokenBalanceBefore;

        if (buyTokenAmountReceived < buyAmount) {
            revert InsufficientBuyAmountReceived(buyTokenAmountReceived, buyAmount);
        }
    }
    // slither-disable-end calls-loop
}
