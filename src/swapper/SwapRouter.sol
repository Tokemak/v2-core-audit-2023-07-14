// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Address } from "openzeppelin-contracts/utils/Address.sol";
import { IERC20, SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { Errors } from "src/utils/Errors.sol";
import { ISyncSwapper } from "src/interfaces/swapper/ISyncSwapper.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IDestinationVaultRegistry } from "src/interfaces/vault/IDestinationVaultRegistry.sol";
import { SecurityBase } from "src/security/SecurityBase.sol";

contract SwapRouter is ISwapRouter, SecurityBase, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;

    ISystemRegistry private immutable systemRegistry;

    // 5/16/2023: open issue https://github.com/crytic/slither/issues/456
    // slither-disable-next-line uninitialized-state
    mapping(address => mapping(address => SwapData[])) private swapRoutes;

    modifier onlyLMPVault(address vaultAddress) {
        IDestinationVaultRegistry destinationVaultRegistry = systemRegistry.destinationVaultRegistry();
        if (!destinationVaultRegistry.isRegistered(vaultAddress)) revert Errors.AccessDenied();
        _;
    }

    constructor(ISystemRegistry _systemRegistry) SecurityBase(address(_systemRegistry.accessController())) {
        systemRegistry = _systemRegistry;
    }

    function setSwapRoute(address assetToken, SwapData[] calldata _swapRoute) external onlyOwner {
        Errors.verifyNotZero(assetToken, "assetToken");

        uint256 length = _swapRoute.length;
        address quoteToken = _swapRoute[length - 1].token;
        delete swapRoutes[assetToken][quoteToken];
        SwapData[] storage swapRoute = swapRoutes[assetToken][quoteToken];

        for (uint256 i = 0; i < length; ++i) {
            SwapData memory swap = _swapRoute[i];

            Errors.verifyNotZero(swap.token, "swap token");
            Errors.verifyNotZero(swap.pool, "swap pool");
            Errors.verifyNotZero(address(swap.swapper), "swap swapper");

            //slither-disable-next-line calls-loop
            swap.swapper.validate(swap);

            swapRoute.push(swap);
        }

        emit SwapRouteSet(assetToken, _swapRoute);
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
    ) external onlyLMPVault(msg.sender) nonReentrant returns (uint256) {
        if (sellAmount == 0) revert Errors.ZeroAmount();
        if (assetToken == quoteToken) revert Errors.InvalidParams();

        SwapData[] memory routes = swapRoutes[assetToken][quoteToken];
        uint256 length = routes.length;

        if (length == 0) revert SwapRouteLookupFailed();

        IERC20(assetToken).safeTransferFrom(msg.sender, address(this), sellAmount);
        uint256 balanceBefore = IERC20(quoteToken).balanceOf(address(this));

        address currentToken = assetToken;
        uint256 currentAmount = sellAmount;
        for (uint256 hop = 0; hop < length; ++hop) {
            bytes memory data = address(routes[hop].swapper).functionDelegateCall(
                abi.encodeWithSelector(
                    ISyncSwapper.swap.selector,
                    routes[hop].pool,
                    currentToken,
                    currentAmount,
                    routes[hop].token,
                    0,
                    routes[hop].data
                ),
                "SwapFailed"
            );

            currentToken = routes[hop].token;
            currentAmount = abi.decode(data, (uint256));
        }
        uint256 balanceAfter = IERC20(quoteToken).balanceOf(address(this));

        uint256 balanceDiff = balanceAfter - balanceBefore;
        if (balanceDiff < minBuyAmount) revert MaxSlippageExceeded();

        IERC20(quoteToken).safeTransfer(msg.sender, balanceDiff);

        emit SwapForQuoteSuccessful(assetToken, sellAmount, quoteToken, minBuyAmount, balanceDiff);

        return balanceDiff;
    }
}
