// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Address } from "openzeppelin-contracts/utils/Address.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { Initializable } from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IPoolAdapter } from "src/interfaces/destinations/IPoolAdapter.sol";
import { ICryptoSwapPool, IPool } from "src/interfaces/external/curve/ICryptoSwapPool.sol";
import { IWETH9 } from "src/interfaces/utils/IWETH9.sol";
import { LibAdapter } from "src/libs/LibAdapter.sol";
import { Errors } from "src/utils/Errors.sol";

//slither-disable-start similar-names
contract CurveV2FactoryCryptoAdapter is IPoolAdapter, ReentrancyGuard, Initializable {
    address public constant CURVE_REGISTRY_ETH_ADDRESS_POINTER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    //slither-disable-next-line immutable-states
    IWETH9 public weth;

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

    error InvalidWethAddress();
    error TooManyAmountsProvided();

    struct CurveExtraParams {
        address poolAddress;
        address lpTokenAddress;
        bool useEth;
    }

    ///@notice We should inject WETH address according to the used chain
    function initialize(address _weth) public initializer {
        Errors.verifyNotZero(address(_weth), "_weth");

        weth = IWETH9(_weth);

        // verify if address belongs to WETH contract:
        if (!Address.isContract(_weth)) revert InvalidWethAddress();

        bytes memory result = Address.functionCall(_weth, abi.encodeWithSignature("symbol()"));
        string memory symbol = abi.decode(result, (string));

        if (keccak256(bytes(symbol)) != keccak256(bytes("WETH"))) {
            revert InvalidWethAddress();
        }
    }

    ///@notice Auto-wrap on receive as system operates with WETH
    receive() external payable {
        weth.deposit{ value: msg.value }();
    }

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minLpMintAmount,
        bytes calldata extraParams
    ) public nonReentrant {
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
                LibAdapter._approve(IERC20(coin), poolAddress, amount);
            }
            coinsBalancesBefore[i] = coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER
                ? address(this).balance
                : IERC20(coin).balanceOf(address(this));
            //slither-disable-end calls-loop
        }

        uint256 deployed = _runDeposit(amounts, minLpMintAmount, curveExtraParams.poolAddress, curveExtraParams.useEth);

        IERC20 lpToken = IERC20(curveExtraParams.lpTokenAddress);

        emit DeployLiquidity(
            _compareCoinsBalances(
                coinsBalancesBefore, _getCoinsBalances(tokens, curveExtraParams.useEth), amounts, true
            ),
            tokens,
            [deployed, lpToken.balanceOf(address(this)), lpToken.totalSupply()],
            poolAddress
        );
    }

    function removeLiquidity(
        uint256[] calldata amounts,
        uint256 maxLpBurnAmount,
        bytes calldata extraParams
    ) public nonReentrant returns (uint256[] memory actualAmounts) {
        (CurveExtraParams memory curveExtraParams) = abi.decode(extraParams, (CurveExtraParams));

        if (maxLpBurnAmount == 0) revert MustBeMoreThanZero();
        _validateAmounts(amounts);

        uint256[] memory coinsBalancesBefore = new uint256[](amounts.length);
        address[] memory tokens = new address[](amounts.length);
        bool useEth = false;
        for (uint256 i = 0; i < amounts.length; ++i) {
            //slither-disable-start calls-loop
            address coin = IPool(curveExtraParams.poolAddress).coins(i);
            tokens[i] = coin;

            if (coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
                coinsBalancesBefore[i] = weth.balanceOf(address(this));
                useEth = true;
            } else {
                coinsBalancesBefore[i] = IERC20(coin).balanceOf(address(this));
            }
            //slither-disable-end calls-loop
        }
        uint256 lpTokenBalanceBefore = IERC20(curveExtraParams.lpTokenAddress).balanceOf(address(this));

        _runWithdrawal(curveExtraParams.poolAddress, amounts, maxLpBurnAmount);

        uint256 lpTokenBalanceAfter = IERC20(curveExtraParams.lpTokenAddress).balanceOf(address(this));
        uint256 lpTokenAmount = lpTokenBalanceBefore - lpTokenBalanceAfter;
        if (lpTokenAmount > maxLpBurnAmount) {
            revert LpTokenAmountMismatch();
        }
        actualAmounts = _compareCoinsBalances(coinsBalancesBefore, _getCoinsBalances(tokens, useEth), amounts, false);

        emit WithdrawLiquidity(
            actualAmounts,
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
    /// @return coinAmount Actual amount of the withdrawn token
    /// @return coin Address of the withdrawn token
    function removeLiquidityOneCoin(
        address poolAddress,
        uint256 lpBurnAmount,
        uint256 coinIndex,
        uint256 minAmount
    ) public nonReentrant returns (uint256 coinAmount, address coin) {
        // slither-disable-next-line incorrect-equality
        if (lpBurnAmount == 0 || minAmount == 0) {
            revert MustBeMoreThanZero();
        }
        uint256 coinBalanceBefore;
        coin = ICryptoSwapPool(poolAddress).coins(coinIndex);
        if (coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
            coinBalanceBefore = weth.balanceOf(address(this));
        } else {
            coinBalanceBefore = IERC20(coin).balanceOf(address(this));
        }

        // In Curve V2 Factory Pools LP token address = pool address
        IERC20 lpToken = IERC20(poolAddress);
        uint256 lpTokenBalanceBefore = lpToken.balanceOf(address(this));

        ICryptoSwapPool(poolAddress).remove_liquidity_one_coin(lpBurnAmount, coinIndex, minAmount);

        uint256 lpTokenBalanceAfter = lpToken.balanceOf(address(this));
        uint256 lpTokenAmount = lpTokenBalanceBefore - lpTokenBalanceAfter;
        if (lpTokenAmount != lpBurnAmount) {
            revert LpTokenAmountMismatch();
        }

        uint256 coinBalanceAfter;
        if (coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
            coinBalanceAfter = weth.balanceOf(address(this));
        } else {
            coinBalanceAfter = IERC20(coin).balanceOf(address(this));
        }
        coinAmount = coinBalanceAfter - coinBalanceBefore;
        if (coinAmount < minAmount) revert InvalidBalanceChange();

        emit WithdrawLiquidity(
            _toDynamicArray(coinAmount),
            _toDynamicArray(coin),
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
    function _getCoinsBalances(
        address[] memory tokens,
        bool useEth
    ) private view returns (uint256[] memory coinsBalances) {
        uint256 nTokens = tokens.length;
        coinsBalances = new uint256[](nTokens);

        for (uint256 i = 0; i < nTokens; ++i) {
            address coin = tokens[i];
            if (coin == CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
                coinsBalances[i] = useEth ? address(this).balance : weth.balanceOf(address(this));
            } else {
                coinsBalances[i] = IERC20(coin).balanceOf(address(this));
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
                uint256[2] memory staticParamArray = [amounts[0], amounts[1]];
                deployed = pool.add_liquidity{ value: amounts[0] }(staticParamArray, minLpMintAmount);
            } else if (nTokens == 3) {
                uint256[3] memory staticParamArray = [amounts[0], amounts[1], amounts[2]];
                deployed = pool.add_liquidity{ value: amounts[0] }(staticParamArray, minLpMintAmount);
            } else if (nTokens == 4) {
                uint256[4] memory staticParamArray = [amounts[0], amounts[1], amounts[2], amounts[3]];
                deployed = pool.add_liquidity{ value: amounts[0] }(staticParamArray, minLpMintAmount);
            }
            // slither-disable-end arbitrary-send-eth
        } else {
            if (nTokens == 2) {
                uint256[2] memory staticParamArray = [amounts[0], amounts[1]];
                deployed = pool.add_liquidity(staticParamArray, minLpMintAmount);
            } else if (nTokens == 3) {
                uint256[3] memory staticParamArray = [amounts[0], amounts[1], amounts[2]];
                deployed = pool.add_liquidity(staticParamArray, minLpMintAmount);
            } else if (nTokens == 4) {
                uint256[4] memory staticParamArray = [amounts[0], amounts[1], amounts[2], amounts[3]];
                deployed = pool.add_liquidity(staticParamArray, minLpMintAmount);
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
            uint256[2] memory staticParamArray = [amounts[0], amounts[1]];
            pool.remove_liquidity(maxLpBurnAmount, staticParamArray);
        } else if (nTokens == 3) {
            uint256[3] memory staticParamArray = [amounts[0], amounts[1], amounts[2]];
            pool.remove_liquidity(maxLpBurnAmount, staticParamArray);
        } else if (nTokens == 4) {
            uint256[4] memory staticParamArray = [amounts[0], amounts[1], amounts[2], amounts[3]];
            pool.remove_liquidity(maxLpBurnAmount, staticParamArray);
        }
    }

    function _toDynamicArray(uint256 value) private pure returns (uint256[] memory dynamicArray) {
        dynamicArray = new uint256[](1);
        dynamicArray[0] = value;
    }

    function _toDynamicArray(address value) private pure returns (address[] memory dynamicArray) {
        dynamicArray = new address[](1);
        dynamicArray[0] = value;
    }
    //slither-disable-end similar-names
}
