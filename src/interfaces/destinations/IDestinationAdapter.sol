// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IDestinationAdapter {
    event DeployLiquidity(
        uint256[] amountsDeposited,
        address[] tokens,
        uint256 lpMintAmount,
        uint256 lpShare,
        uint256 lpTotalSupply,
        bytes extraData
    ); // extraData: contains extra params for each controller (may be empty)

    event WithdrawLiquidity(
        uint256[] amountsWithdrawn,
        address[] tokens,
        uint256 lpBurnAmount,
        uint256 lpShare,
        uint256 lpTotalSupply,
        bytes extraData
    ); // extraData: contains extra params for each controller (may be empty)

    /// @notice Deploy liquidity to the assosiated destination
    /// @dev Calls into external contract
    /// @param amounts Amounts of corresponding tokens to deploy
    /// @param minLpMintAmount Min amount of LP tokens to mint in the deployment
    /// @param extraParams Encoded params that are specific to the given destinaion
    function addLiquidity(uint256[] calldata amounts, uint256 minLpMintAmount, bytes calldata extraParams) external;

    /// @notice Withdraw liquidity from the assosiated destination
    /// @dev Calls into external contract
    /// @param amounts Amounts of corresponding tokens to withdraw
    /// @param maxLpBurnAmount Max amount of LP tokens to burn in the withdrawal
    /// @param extraParams Encoded params that are specific to the given destinaion
    function removeLiquidity(
        uint256[] calldata amounts,
        uint256 maxLpBurnAmount,
        bytes calldata extraParams
    ) external;
}
