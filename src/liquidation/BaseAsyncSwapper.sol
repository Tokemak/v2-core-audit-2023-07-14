// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import { ERC20Utils } from "../libs/ERC20Utils.sol";
import { IAsyncSwapper, SwapParams } from "../interfaces/liquidation/IAsyncSwapper.sol";

contract BaseAsyncSwapper is IAsyncSwapper, ReentrancyGuard {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable AGGREGATOR;

    constructor(address aggregator) {
        if (aggregator == address(0)) revert TokenAddressZero();
        AGGREGATOR = aggregator;
    }

    // slither-disable-start calls-loop
    function swap(SwapParams memory swapParams) public virtual nonReentrant {
        if (swapParams.buyTokenAddress == address(0)) revert TokenAddressZero();
        if (swapParams.sellTokenAddress == address(0)) revert TokenAddressZero();
        if (swapParams.sellAmount == 0) revert InsufficientSellAmount();
        if (swapParams.buyAmount == 0) revert InsufficientBuyAmount();

        IERC20 sellToken = IERC20(swapParams.sellTokenAddress);
        IERC20 buyToken = IERC20(swapParams.buyTokenAddress);

        uint256 sellTokenBalance = sellToken.balanceOf(address(this));

        if (sellTokenBalance < swapParams.sellAmount) {
            revert InsufficientBalance(sellTokenBalance, swapParams.sellAmount);
        }

        ERC20Utils.approve(sellToken, AGGREGATOR, swapParams.sellAmount);

        uint256 buyTokenBalanceBefore = buyToken.balanceOf(address(this));

        // slither-disable-start low-level-calls
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = AGGREGATOR.call(swapParams.data);
        // slither-disable-end low-level-calls

        if (!success) {
            revert SwapFailed();
        }

        uint256 buyTokenBalanceAfter = buyToken.balanceOf(address(this));
        uint256 buyTokenAmountReceived = buyTokenBalanceAfter - buyTokenBalanceBefore;

        if (buyTokenAmountReceived < swapParams.buyAmount) {
            revert InsufficientBuyAmountReceived(buyTokenAmountReceived, swapParams.buyAmount);
        }
    }
    // slither-disable-end calls-loop
}
