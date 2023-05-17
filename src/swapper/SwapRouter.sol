// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Address } from "openzeppelin-contracts/utils/Address.sol";
import { IERC20, SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { ISyncSwapper } from "src/interfaces/swapper/ISyncSwapper.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";

// TODO: add access control
contract SwapRouter is ISwapRouter {
    using Address for address;
    using SafeERC20 for IERC20;

    // 5/16/2023: open issue https://github.com/crytic/slither/issues/456
    // slither-disable-next-line uninitialized-state
    mapping(address => mapping(address => SwapData[])) private swapRoutes;

    // TODO: add access control
    function setSwapRoute(address assetToken, SwapData[] calldata _swapRoute) external {
        // TODO - validation of entry
        address quoteToken = _swapRoute[_swapRoute.length - 1].token;
        delete swapRoutes[assetToken][quoteToken];
        SwapData[] storage swapRoute = swapRoutes[assetToken][quoteToken];

        for (uint256 i = 0; i < _swapRoute.length; i++) {
            swapRoute.push(_swapRoute[i]);
        }

        // TODO: add event
    }

    // TODO: do we need special handling if a route does return eth
    receive() external payable {
        // we accept ETH so we can unwrap WETH
    }

    /// @dev it swaps asset token for quote
    /// @param assetToken address
    /// @param sellAmount exact amount of asset to swap
    /// @return amount of quote token
    function swapForQuote(
        address assetToken,
        uint256 sellAmount,
        address quoteToken,
        uint256 minBuyAmount
    ) external returns (uint256) {
        if (sellAmount == 0) return sellAmount;
        if (assetToken == quoteToken) return sellAmount; // TODO: should this be an error

        SwapData[] memory swapRoute = swapRoutes[assetToken][quoteToken];
        if (swapRoute.length == 0) {
            revert SwapRouteLookupFailed();
        }

        IERC20(assetToken).safeTransferFrom(msg.sender, address(this), sellAmount);

        address currentToken = assetToken;
        uint256 currentAmount = sellAmount;
        for (uint256 hop = 0; hop < swapRoute.length; hop++) {
            bytes memory data = address(swapRoute[hop].swapper).functionDelegateCall(
                abi.encodeWithSelector(
                    ISyncSwapper.swap.selector,
                    swapRoute[hop].pool,
                    currentToken,
                    currentAmount,
                    swapRoute[hop].token,
                    0,
                    swapRoute[hop].data
                ),
                "SwapFailed"
            );

            currentToken = swapRoute[hop].token;
            currentAmount = abi.decode(data, (uint256));
        }

        if (currentAmount < minBuyAmount) revert SwapFailedDuetoInsufficientBuy();

        IERC20(quoteToken).safeTransfer(msg.sender, currentAmount);

        return currentAmount;
    }
}
