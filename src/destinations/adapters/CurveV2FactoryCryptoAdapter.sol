// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/access/AccessControl.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

import "../../interfaces/destinations/IDestinationAdapter.sol";
import "./libs/LibAdapter.sol";
import { ICryptoSwapPool, IPool } from "../../interfaces/external/curve/ICryptoSwapPool.sol";

contract CurveV2FactoryCryptoAdapter is IDestinationAdapter, AccessControl, ReentrancyGuard {
    address public constant CURVE_REGISTRY_ETH_ADDRESS_POINTER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    error MustBeMoreThanZero();
    error MinLpAmountNotReached();
    error MinAmountNotReached();
    error LpTokenAmountMismatch();
    error MustNotBeZero();
    error NoNonZeroAmountProvided();
    error InvalidBalanceChange();

    struct CurveExtraParams {
        address poolAddress;
        address lpTokenAddress;
        bool useEth;
    }

    receive() external payable { }

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minLpMintAmount,
        bytes calldata extraParams
    ) external nonReentrant {
        (CurveExtraParams memory curveExtraParams) = abi.decode(extraParams, (CurveExtraParams));

        _validateAmounts(amounts);
        if (minLpMintAmount == 0) revert MustBeMoreThanZero();

        address[] memory tokens = new address[](amounts.length);
        for (uint256 i = 0; i < amounts.length;) {
            uint256 amount = amounts[i];
            //slither-disable-next-line calls-loop
            address coin = ICryptoSwapPool(curveExtraParams.poolAddress).coins(i);
            tokens[i] = coin;
            if (amount > 0 && coin != CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
                LibAdapter._validateAndApprove(coin, curveExtraParams.poolAddress, amount);
            }
            unchecked {
                ++i;
            }
        }
        uint256[] memory coinsBalancesBefore = _getCoinsBalances(curveExtraParams.poolAddress, amounts.length);

        uint256 deployed;
        if (curveExtraParams.useEth) {
            // slither-disable-next-line arbitrary-send-eth
            deployed = ICryptoSwapPool(curveExtraParams.poolAddress).add_liquidity{value: amounts[0]}(
                [amounts[0], amounts[1]], minLpMintAmount
            );
        } else {
            deployed =
                ICryptoSwapPool(curveExtraParams.poolAddress).add_liquidity([amounts[0], amounts[1]], minLpMintAmount);
        }
        if (deployed < minLpMintAmount) {
            revert MinLpAmountNotReached();
        }

        uint256[] memory coinsBalancesAfter = _getCoinsBalances(curveExtraParams.poolAddress, amounts.length);
        uint256 lpTokenBalanceAfter = IERC20(curveExtraParams.lpTokenAddress).balanceOf(address(this));

        _emitDepositEvent(
            _compareCoinsBalances(coinsBalancesBefore, coinsBalancesAfter, amounts, true),
            tokens,
            [deployed, lpTokenBalanceAfter, IERC20(curveExtraParams.lpTokenAddress).totalSupply()],
            curveExtraParams.poolAddress
        );
    }

    function removeLiquidity(
        uint256[] calldata amounts,
        uint256 maxLpBurnAmount,
        bytes calldata extraParams
    ) external nonReentrant {
        (CurveExtraParams memory curveExtraParams) = abi.decode(extraParams, (CurveExtraParams));

        _validateAmounts(amounts);
        if (maxLpBurnAmount == 0) revert MustBeMoreThanZero();

        uint256[] memory coinsBalancesBefore = new uint256[](amounts.length);
        address[] memory tokens = new address[](amounts.length);
        for (uint256 i = 0; i < amounts.length;) {
            //slither-disable-next-line calls-loop
            address coin = IPool(curveExtraParams.poolAddress).coins(i);
            tokens[i] = coin;

            coinsBalancesBefore[i] = coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER
                ? address(this).balance
                : IERC20(coin).balanceOf(address(this));

            unchecked {
                ++i;
            }
        }
        uint256 lpTokenBalanceBefore = IERC20(curveExtraParams.lpTokenAddress).balanceOf(address(this));

        ICryptoSwapPool(curveExtraParams.poolAddress).remove_liquidity(maxLpBurnAmount, [amounts[0], amounts[1]]);

        uint256 lpTokenBalanceAfter = IERC20(curveExtraParams.lpTokenAddress).balanceOf(address(this));
        uint256 lpTokenAmount = lpTokenBalanceBefore - lpTokenBalanceAfter;
        if (lpTokenAmount > maxLpBurnAmount) {
            revert LpTokenAmountMismatch();
        }

        uint256[] memory coinsBalancesAfter = _getCoinsBalances(curveExtraParams.poolAddress, amounts.length);

        _emitWithdrawEvent(
            _compareCoinsBalances(coinsBalancesBefore, coinsBalancesAfter, amounts, false),
            tokens,
            [lpTokenAmount, lpTokenBalanceAfter, IERC20(curveExtraParams.lpTokenAddress).totalSupply()],
            curveExtraParams.poolAddress
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
    ) external nonReentrant {
        if (lpBurnAmount == 0 || minAmount == 0) {
            revert MustNotBeZero();
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
            revert LpTokenAmountMismatch();
        }

        uint256 coinAmount = coinErc.balanceOf(address(this)) - coinBalanceBefore;
        if (coinAmount < minAmount) revert MinAmountNotReached();

        _emitWithdrawEvent(
            LibAdapter._toDynamicArray(coinAmount),
            LibAdapter._toDynamicArray(coin),
            [lpTokenAmount, lpTokenBalanceAfter, lpTokenErc.totalSupply()],
            poolAddress
        );
    }

    /// @dev Validate to have at least one `amount` > 0 provided
    function _validateAmounts(uint256[] memory amounts) internal pure {
        bool nonZeroAmountPresent = false;
        for (uint256 i = 0; i < amounts.length;) {
            if (amounts[i] != 0) {
                nonZeroAmountPresent = true;
                break;
            }
            unchecked {
                ++i;
            }
        }
        if (!nonZeroAmountPresent) revert NoNonZeroAmountProvided();
    }

    /// @dev Gets balances of pool's ERC-20 tokens or ETH
    function _getCoinsBalances(
        address poolAddress,
        uint256 nCoins
    ) private view returns (uint256[] memory coinsBalances) {
        coinsBalances = new uint256[](nCoins);

        for (uint256 i = 0; i < nCoins;) {
            address coin = IPool(poolAddress).coins(i);
            coinsBalances[i] = coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER
                ? address(this).balance
                : IERC20(coin).balanceOf(address(this));
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Validate to have a valid balance change
    function _compareCoinsBalances(
        uint256[] memory balancesBefore,
        uint256[] memory balancesAfter,
        uint256[] memory amounts,
        bool isLiqDeployment
    ) private pure returns (uint256[] memory balanceChange) {
        balanceChange = new uint256[](amounts.length);

        for (uint256 i = 0; i < amounts.length;) {
            uint256 balanceDiff =
                isLiqDeployment ? balancesBefore[i] - balancesAfter[i] : balancesAfter[i] - balancesBefore[i];

            if (balanceDiff < amounts[i]) {
                revert InvalidBalanceChange();
            }
            balanceChange[i] = balanceDiff;
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Separate function to avoid stack-too-deep errors
    function _emitDepositEvent(
        uint256[] memory amounts,
        address[] memory tokens,
        uint256[3] memory lpAmounts,
        address poolAddress
    ) private {
        emit DeployLiquidity(amounts, tokens, lpAmounts[0], lpAmounts[1], lpAmounts[2], abi.encode(poolAddress));
    }

    /// @dev Separate function to avoid stack-too-deep errors
    function _emitWithdrawEvent(
        uint256[] memory amounts,
        address[] memory tokens,
        uint256[3] memory lpAmounts,
        address poolAddress
    ) private {
        emit WithdrawLiquidity(amounts, tokens, lpAmounts[0], lpAmounts[1], lpAmounts[2], abi.encode(poolAddress));
    }
}
