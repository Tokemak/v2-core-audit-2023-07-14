// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IDestinationVault } from "../vault/IDestinationVault.sol";
import { IERC3156FlashBorrower } from "openzeppelin-contracts/interfaces/IERC3156FlashBorrower.sol";

// slither-disable-next-line name-reused
interface IStrategyNew {
    /// @notice gets the list of supported destination vaults for the LMP/Strategy
    /// @return destinations List of supported destination vaults
    function getDestinations() external view returns (IDestinationVault[] memory destinations);

    /// @notice add supported destination vaults for the LMP/Strategy
    /// @param destinations The list of destination vaults to add
    function addDestinations(IDestinationVault[] calldata destinations) external;

    /// @notice remove supported destination vaults for the LMP/Strategy
    /// @param destinations The list of destination vaults to remove
    function removeDestinations(IDestinationVault[] calldata destinations) external;

    /// @notice rebalance the LMP from the tokenOut (decrease) to the tokenIn (increase)
    /// @param tokenIn The address of the destination vault that will increase
    /// @param tokenOut The address of the destination vault that will decrease
    /// @param amountIn The amount of the destination vault LP tokens that will be received
    /// @param amountOut The amount of the destination vault LP tokens that will be sent to the swapper
    function rebalance(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) external;

    /// @notice rebalance the LMP from the tokenOut (decrease) to the tokenIn (increase)
    /// This uses a flash loan to receive the tokenOut to reduce the working capital requirements of the swapper
    /// @param receiver The contract receiving the tokens, needs to implement the
    /// `onFlashLoan(address user, address token, uint256 amount, uint256 fee, bytes calldata)` interface
    /// @param tokenIn The address of the destination vault that will increase
    /// @param tokenOut The address of the destination vault that will decrease
    /// @param amountIn The amount of the destination vault LP tokens that will be received
    /// @param amountOut The amount of the destination vault LP tokens that will be sent to the swapper
    /// @param data A data parameter to be passed on to the `receiver` for any custom use
    function flashRebalance(
        IERC3156FlashBorrower receiver,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes calldata data
    ) external;

    /// @notice verify that a rebalance (swap between destinations) meets all the strategy constraints
    /// @param tokenIn The address of the destination vault that will increase
    /// @param tokenOut The address of the destination vault that will decrease
    /// @param amountIn The amount of the destination vault LP tokens that will be received
    /// @param amountOut The amount of the destination vault LP tokens that will be sent to the swapper
    /// @return success True if successful
    /// @return message The failure reason or SUCCESS
    function verifyRebalance(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) external view returns (bool success, string memory message);
}
