// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

import "../../interfaces/destinations/IPoolAdapter.sol";
import "../../libs/LibAdapter.sol";
import { ICryptoSwapPool, IPool } from "../../interfaces/external/curve/ICryptoSwapPool.sol";

contract CurveV2FactoryCryptoAdapter is IPoolAdapter, ReentrancyGuard {
    address public constant CURVE_REGISTRY_ETH_ADDRESS_POINTER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event DeployLiquidity(
        uint256[] amountsDeposited,
        address[] tokens,
        // 0 - lpMintAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address poolAddress
    );

    event WithdrawLiquidity(
        uint256[] amountsWithdrawn,
        address[] tokens,
        // 0 - lpBurnAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address poolAddress
    );

    error MustBeMoreThanZero();
    error MinLpAmountNotReached();
    error MinAmountNotReached();
    error LpTokenAmountMismatch();
    error MustNotBeZero();
    error TooManyAmountsProvided();
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

        if (minLpMintAmount == 0) revert MustBeMoreThanZero();
        _validateAmounts(amounts);

        address poolAddress = curveExtraParams.poolAddress;

        uint256 nTokens = amounts.length;
        address[] memory tokens = new address[](nTokens);
        uint256[] memory coinsBalancesBefore = new uint256[](nTokens);
        for (uint256 i = 0; i < nTokens; ++i) {
            uint256 amount = amounts[i];
            //slither-disable-start calls-loop
            address coin = ICryptoSwapPool(poolAddress).coins(i);
            tokens[i] = coin;
            if (amount > 0 && coin != CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
                LibAdapter._validateAndApprove(coin, poolAddress, amount);
            }
            coinsBalancesBefore[i] = coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER
                ? address(this).balance
                : IERC20(coin).balanceOf(address(this));
            //slither-disable-end calls-loop
        }

        uint256 deployed = _runDeposit(amounts, minLpMintAmount, curveExtraParams.poolAddress, curveExtraParams.useEth);

        IERC20 lpToken = IERC20(curveExtraParams.lpTokenAddress);

        emit DeployLiquidity(
            _compareCoinsBalances(coinsBalancesBefore, _getCoinsBalances(tokens), amounts, true),
            tokens,
            [deployed, lpToken.balanceOf(address(this)), lpToken.totalSupply()],
            poolAddress
            );
    }

    function removeLiquidity(
        uint256[] calldata amounts,
        uint256 maxLpBurnAmount,
        bytes calldata extraParams
    ) external nonReentrant {
        (CurveExtraParams memory curveExtraParams) = abi.decode(extraParams, (CurveExtraParams));

        if (maxLpBurnAmount == 0) revert MustBeMoreThanZero();
        _validateAmounts(amounts);

        uint256 nTokens = amounts.length;
        uint256[] memory coinsBalancesBefore = new uint256[](nTokens);
        address[] memory tokens = new address[](nTokens);
        for (uint256 i = 0; i < nTokens; ++i) {
            //slither-disable-start calls-loop
            address coin = IPool(curveExtraParams.poolAddress).coins(i);
            tokens[i] = coin;

            coinsBalancesBefore[i] = coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER
                ? address(this).balance
                : IERC20(coin).balanceOf(address(this));
            //slither-disable-end calls-loop
        }
        uint256 lpTokenBalanceBefore = IERC20(curveExtraParams.lpTokenAddress).balanceOf(address(this));

        _runWithdrawal(curveExtraParams.poolAddress, amounts, maxLpBurnAmount);

        uint256 lpTokenBalanceAfter = IERC20(curveExtraParams.lpTokenAddress).balanceOf(address(this));
        uint256 lpTokenAmount = lpTokenBalanceBefore - lpTokenBalanceAfter;
        if (lpTokenAmount > maxLpBurnAmount) {
            revert LpTokenAmountMismatch();
        }

        emit WithdrawLiquidity(
            _compareCoinsBalances(coinsBalancesBefore, _getCoinsBalances(tokens), amounts, false),
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
        IERC20 lpToken = IERC20(poolAddress);
        uint256 lpTokenBalanceBefore = lpToken.balanceOf(address(this));

        ICryptoSwapPool(poolAddress).remove_liquidity_one_coin(lpBurnAmount, coinIndex, minAmount);

        uint256 lpTokenBalanceAfter = lpToken.balanceOf(address(this));
        uint256 lpTokenAmount = lpTokenBalanceBefore - lpTokenBalanceAfter;
        if (lpTokenAmount != lpBurnAmount) {
            revert LpTokenAmountMismatch();
        }
        uint256 coinAmount = coinErc.balanceOf(address(this)) - coinBalanceBefore;
        if (coinAmount < minAmount) revert MinAmountNotReached();

        emit WithdrawLiquidity(
            LibAdapter._toDynamicArray(coinAmount),
            LibAdapter._toDynamicArray(coin),
            [lpTokenAmount, lpTokenBalanceAfter, lpToken.totalSupply()],
            poolAddress
            );
    }

    /// @dev Validate to have at least one `amount` > 0 provided and `amounts` is <=4
    function _validateAmounts(uint256[] memory amounts) internal pure {
        uint256 nTokens = amounts.length;
        if (nTokens > 4) {
            revert TooManyAmountsProvided();
        }
        bool nonZeroAmountPresent = false;
        for (uint256 i = 0; i < nTokens; ++i) {
            if (amounts[i] != 0) {
                nonZeroAmountPresent = true;
                break;
            }
        }
        if (!nonZeroAmountPresent) revert NoNonZeroAmountProvided();
    }

    /// @dev Gets balances of pool's ERC-20 tokens or ETH
    function _getCoinsBalances(address[] memory tokens) private view returns (uint256[] memory coinsBalances) {
        uint256 nTokens = tokens.length;
        coinsBalances = new uint256[](nTokens);

        for (uint256 i = 0; i < nTokens; ++i) {
            address coin = tokens[i];
            coinsBalances[i] = coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER
                ? address(this).balance
                : IERC20(coin).balanceOf(address(this));
        }
    }

    /// @dev Validate to have a valid balance change
    function _compareCoinsBalances(
        uint256[] memory balancesBefore,
        uint256[] memory balancesAfter,
        uint256[] memory amounts,
        bool isLiqDeployment
    ) private pure returns (uint256[] memory balanceChange) {
        uint256 nTokens = amounts.length;
        balanceChange = new uint256[](nTokens);

        for (uint256 i = 0; i < nTokens; ++i) {
            uint256 balanceDiff =
                isLiqDeployment ? balancesBefore[i] - balancesAfter[i] : balancesAfter[i] - balancesBefore[i];

            if (balanceDiff < amounts[i]) {
                revert InvalidBalanceChange();
            }
            balanceChange[i] = balanceDiff;
        }
    }

    function _runDeposit(
        uint256[] memory amounts,
        uint256 minLpMintAmount,
        address poolAddress,
        bool useEth
    ) private returns (uint256 deployed) {
        uint256 nTokens = amounts.length;
        ICryptoSwapPool pool = ICryptoSwapPool(poolAddress);
        if (useEth) {
            // slither-disable-start arbitrary-send-eth
            if (nTokens == 2) {
                deployed = pool.add_liquidity{value: amounts[0]}([amounts[0], amounts[1]], minLpMintAmount);
            } else if (nTokens == 3) {
                deployed = pool.add_liquidity{value: amounts[0]}([amounts[0], amounts[1], amounts[2]], minLpMintAmount);
            } else if (nTokens == 4) {
                deployed = pool.add_liquidity{value: amounts[0]}(
                    [amounts[0], amounts[1], amounts[2], amounts[3]], minLpMintAmount
                );
            }
            // slither-disable-end arbitrary-send-eth
        } else {
            if (nTokens == 2) {
                deployed = pool.add_liquidity([amounts[0], amounts[1]], minLpMintAmount);
            } else if (nTokens == 3) {
                deployed = pool.add_liquidity([amounts[0], amounts[1], amounts[2]], minLpMintAmount);
            } else if (nTokens == 4) {
                deployed = pool.add_liquidity([amounts[0], amounts[1], amounts[2], amounts[3]], minLpMintAmount);
            }
        }
        if (deployed < minLpMintAmount) {
            revert MinLpAmountNotReached();
        }
    }

    function _runWithdrawal(address poolAddress, uint256[] memory amounts, uint256 maxLpBurnAmount) private {
        uint256 nTokens = amounts.length;
        ICryptoSwapPool pool = ICryptoSwapPool(poolAddress);
        if (nTokens == 2) {
            pool.remove_liquidity(maxLpBurnAmount, [amounts[0], amounts[1]]);
        } else if (nTokens == 3) {
            pool.remove_liquidity(maxLpBurnAmount, [amounts[0], amounts[1], amounts[2]]);
        } else if (nTokens == 4) {
            pool.remove_liquidity(maxLpBurnAmount, [amounts[0], amounts[1], amounts[2], amounts[3]]);
        }
    }
}
