// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { IDestinationAdapter } from "../../interfaces/destinations/IDestinationAdapter.sol";
import { ICryptoSwapPool, IPool } from "../../interfaces/external/curve/ICryptoSwapPool.sol";
import { LibAdapter } from "./libs/LibAdapter.sol";

contract CurveV2FactoryCryptoAdapter is IDestinationAdapter {
    address public constant CURVE_REGISTRY_ETH_ADDRESS_POINTER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public constant N_COINS = 2; // TODO: change to dynamic arrays

    struct ExtraParams {
        address poolAddress;
    }

    function addLiquidity(uint256[] calldata amounts, uint256 minLpMintAmount, bytes calldata _extraParams) external {
        (ExtraParams memory extraParams) = abi.decode(_extraParams, (ExtraParams));

        _validateAmounts(amounts);
        if (minLpMintAmount == 0) revert("minLpMintAmount must be > 0");

        ICryptoSwapPool pool = ICryptoSwapPool(extraParams.poolAddress);
        address[] memory tokens = new address[](amounts.length);
        for (uint256 i = 0; i < amounts.length; ++i) {
            uint256 amount = amounts[i];
            address coin = pool.coins(i);
            tokens[i] = coin;
            if (amount > 0) {
                LibAdapter._validateAndApprove(coin, extraParams.poolAddress, amount);
            }
        }
        uint256 lpTokenBalanceBefore = IERC20(extraParams.poolAddress).balanceOf(address(this));

        uint256[N_COINS] memory coinsBalancesBefore = _getCoinsBalances(extraParams.poolAddress);

        pool.add_liquidity(amounts, minLpMintAmount);

        uint256 lpTokenBalanceAfter = IERC20(extraParams.poolAddress).balanceOf(address(this));
        uint256 lpTokenAmount = lpTokenBalanceAfter - lpTokenBalanceBefore;
        if (lpTokenAmount < minLpMintAmount) {
            revert("minLpMintAmount was not reached");
        }

        _emitDepositEvent(
            _compareCoinsBalances(coinsBalancesBefore, _getCoinsBalances(extraParams.poolAddress), amounts, true),
            tokens,
            [lpTokenAmount, lpTokenBalanceAfter, IERC20(extraParams.poolAddress).totalSupply()],
            extraParams.poolAddress
        );
    }

    function removeLiquidity(
        uint256[] calldata amounts,
        uint256 maxLpBurnAmount,
        bytes calldata _extraParams
    )
        external
    {
        (ExtraParams memory extraParams) = abi.decode(_extraParams, (ExtraParams));

        if (maxLpBurnAmount == 0) revert("lpBurnAmount must be > 0");
        _validateAmounts(amounts);

        // In Curve V2 Factory Pools LP token address = pool address
        IERC20 lpTokenErc = IERC20(extraParams.poolAddress);
        uint256 lpTokenBalanceBefore = lpTokenErc.balanceOf(address(this));

        uint256[N_COINS] memory coinsBalancesBefore = _getCoinsBalances(extraParams.poolAddress);

        ICryptoSwapPool(extraParams.poolAddress).remove_liquidity(maxLpBurnAmount, amounts);

        uint256 lpTokenBalanceAfter = lpTokenErc.balanceOf(address(this));
        uint256 lpTokenAmount = lpTokenBalanceBefore - lpTokenBalanceAfter;
        if (lpTokenAmount != maxLpBurnAmount) {
            revert("LP token amount mismatch");
        }

        uint256[N_COINS] memory coinsBalancesAfter = _getCoinsBalances(extraParams.poolAddress);

        _emitWithdrawEvent(
            _compareCoinsBalances(coinsBalancesBefore, coinsBalancesAfter, amounts, false),
            _getCoinsAddresses(extraParams.poolAddress, N_COINS),
            [lpTokenAmount, lpTokenBalanceAfter, lpTokenErc.totalSupply()],
            extraParams.poolAddress
        );
    }

    /// @notice Withdraw liquidity from Curve pool
    /// @dev Calls to external contract
    /// @dev We trust sender to send a true Curve poolAddress.
    ///      If it's not the case it will fail in the remove_liquidity_one_coin part
    /// @param poolAddress Curve pool address
    /// @param lpBurnAmount Amount of LP tokens to burn in the withdrawal
    /// @param coinIndex Index value of the coin to withdraw
    /// @param minAmount Minimum amount of coin to receive
    function removeLiquidityOneCoin(
        address poolAddress,
        uint256 lpBurnAmount,
        uint256 coinIndex,
        uint256 minAmount
    )
        external
    {
        if (lpBurnAmount == 0 || minAmount == 0) {
            revert("Must not be 0");
        }

        address coin = ICryptoSwapPool(poolAddress).coins(coinIndex);
        IERC20 coinErc = IERC20(coin);
        uint256 coinBalanceBefore = coinErc.balanceOf(address(this));

        // In Curve V2 Factory Pools LP token address = pool address
        IERC20 lpTokenErc = IERC20(poolAddress);
        uint256 lpTokenBalanceBefore = lpTokenErc.balanceOf(address(this));

        ICryptoSwapPool(poolAddress).remove_liquidity_one_coin(lpBurnAmount, coinIndex, minAmount);

        uint256 lpTokenBalanceAfter = lpTokenErc.balanceOf(address(this));
        uint256 lpTokenAmount = lpTokenBalanceBefore - lpTokenBalanceAfter;
        if (lpTokenAmount != lpBurnAmount) {
            revert("LP token amount mismatch");
        }

        uint256 coinAmount = coinErc.balanceOf(address(this)) - coinBalanceBefore;
        if (coinAmount < minAmount) revert("Balance must reach minAmount");

        _emitWithdrawEvent(
            LibAdapter._toDynamicArray(coinAmount),
            LibAdapter._toDynamicArray(coin),
            [lpTokenAmount, lpTokenBalanceAfter, lpTokenErc.totalSupply()],
            poolAddress
        );
    }

    function _getBalance(address coin) internal view returns (uint256) {
        uint256 balance;
        if (coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
            balance = address(this).balance;
        } else {
            balance = IERC20(coin).balanceOf(address(this));
        }
        return balance;
    }

    function _getCoinsAddresses(address poolAddress, uint256 nCoins) internal view returns (address[] memory tokens) {
        tokens = new address[](nCoins);
        for (uint256 i = 0; i < nCoins; ++i) {
            tokens[i] = IPool(poolAddress).coins(i);
        }
    }

    /// @dev Validate to have at least one `amount` > 0 provided
    function _validateAmounts(uint256[] memory amounts) internal pure {
        bool nonZeroAmountPresent = false;
        for (uint256 i = 0; i < amounts.length; ++i) {
            if (amounts[i] != 0) {
                nonZeroAmountPresent = true;
                break;
            }
        }
        if (!nonZeroAmountPresent) revert("No non-zero amount provided");
    }

    function _getCoinsBalances(address poolAddress) private view returns (uint256[N_COINS] memory coinsBalances) {
        for (uint256 i = 0; i < N_COINS; ++i) {
            address coin = IPool(poolAddress).coins(i);
            coinsBalances[i] = _getBalance(coin);
        }
    }

    function _compareCoinsBalances(
        uint256[N_COINS] memory balancesBefore,
        uint256[N_COINS] memory balancesAfter,
        uint256[] memory amounts,
        bool isLiqDeployment
    )
        private
        pure
        returns (uint256[] memory balanceChange)
    {
        balanceChange = new uint256[](N_COINS);

        for (uint256 i = 0; i < N_COINS; ++i) {
            uint256 balanceDiff =
                isLiqDeployment ? balancesBefore[i] - balancesAfter[i] : balancesAfter[i] - balancesBefore[i];
            if (balanceDiff < amounts[i]) {
                revert("Invalid balance change");
            }
            balanceChange[i] = balanceDiff;
        }
    }

    /// @dev Separate function to avoid stack-too-deep errors
    function _emitDepositEvent(
        uint256[] memory amounts,
        address[] memory tokens,
        uint256[3] memory lpAmounts,
        address poolAddress
    )
        private
    {
        emit DeployLiquidity(amounts, tokens, lpAmounts[0], lpAmounts[1], lpAmounts[2], abi.encode(poolAddress));
    }

    /// @dev Separate function to avoid stack-too-deep errors
    function _emitWithdrawEvent(
        uint256[] memory amounts,
        address[] memory tokens,
        uint256[3] memory lpAmounts,
        address poolAddress
    )
        private
    {
        emit WithdrawLiquidity(amounts, tokens, lpAmounts[0], lpAmounts[1], lpAmounts[2], abi.encode(poolAddress));
    }
}
