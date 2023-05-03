// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Address.sol";
import "../interfaces/swapper/ISyncSwapper.sol";
import "../libs/ERC20Utils.sol";
import { console2 as console } from "forge-std/console2.sol";

struct SwapData {
        // Struct
        address token;
        address pool;
        ISyncSwapper swapper;
        bytes[] data; 
    }

contract LPTokenSwapper is Ownable {

    mapping(address => mapping(address => SwapData[])) private swapLookUp;

    function setSwapLookUpEntry(
        address _assetT,
        address _quoteT,
        SwapData[] memory sData
    ) external onlyOwner {
        // TODO - validation of entry
        swapLookUp[_assetT][_quoteT] = sData;
    }

    error SwapFailed();
    error SwapFailedDuetoInsufficientBuy();
    error ApprovalFailed();
    error RouterTokenTransferFailed();
    error SwapMappingLookupFailed();
    error SwapMappingEntryError();

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

        // Look up swap path
        SwapData[] memory swapD = swapLookUp[assetToken][quoteToken];
        if (swapD.length == 0) {
            revert SwapMappingLookupFailed();
        }

        if (assetToken == quoteToken) return sellAmount;

        // Transfer tokens to allow swap
        if (!IERC20(assetToken).transferFrom(msg.sender, address(this), sellAmount)) {
            revert RouterTokenTransferFailed();
        }

        address currentToken = assetToken;
        uint256 currentAmount = sellAmount;
        uint256 actualBuyAmount = 0;
        for (uint256 hop = 0; hop < swapD.length; hop++) {
             bytes memory data = abi.encodeWithSelector(
                    ISyncSwapper.swap.selector, swapD[hop].pool, currentToken, currentAmount, swapD[hop].token, 0
                );
             bytes memory returndata = Address.functionDelegateCall(address(swapD[hop].swapper), data, "Swap Failed with functionDelegateCall" );

            if (returndata.length > 0) {
                actualBuyAmount = abi.decode(returndata, (uint256));
           }

            actualBuyAmount = abi.decode(returndata, (uint256));
        }

        if (actualBuyAmount < minBuyAmount) revert SwapFailedDuetoInsufficientBuy();

        // Transfer tokens to caller

        return actualBuyAmount;
    }
}
