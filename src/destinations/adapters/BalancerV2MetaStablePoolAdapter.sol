// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IPoolAdapter } from "src/interfaces/destinations/IPoolAdapter.sol";
import { IAsset } from "src/interfaces/external/balancer/IAsset.sol";
import { IVault } from "src/interfaces/external/balancer/IVault.sol";
import { IBalancerPool } from "src/interfaces/external/balancer/IBalancerPool.sol";
import { LibAdapter } from "src/libs/LibAdapter.sol";
import { Errors } from "src/utils/Errors.sol";

contract BalancerV2MetaStablePoolAdapter is IPoolAdapter, ReentrancyGuard, Initializable {
    using SafeERC20 for IERC20;

    event DeployLiquidity(
        uint256[] amountsDeposited,
        address[] tokens,
        // 0 - lpMintAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address poolAddress,
        bytes32 poolId
    );

    event WithdrawLiquidity(
        uint256[] amountsWithdrawn,
        address[] tokens,
        // 0 - lpBurnAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address poolAddress,
        bytes32 poolId
    );

    error TokenPoolAssetMismatch();

    enum JoinKind {
        INIT,
        EXACT_TOKENS_IN_FOR_BPT_OUT,
        TOKEN_IN_FOR_EXACT_BPT_OUT,
        ALL_TOKENS_IN_FOR_EXACT_BPT_OUT,
        ADD_TOKEN
    }
    enum ExitKind {
        EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
        EXACT_BPT_IN_FOR_TOKENS_OUT,
        BPT_IN_FOR_EXACT_TOKENS_OUT,
        REMOVE_TOKEN
    }

    /// @param pool address of Balancer Pool
    /// @param bptAmount uint256 pool token amount expected back
    /// @param tokens IERC20[] of tokens to be withdrawn from pool
    /// @param amountsOut uint256[] min amount of tokens expected on withdrawal
    /// @param userData bytes data, used for info about kind of pool exit
    struct WithdrawParams {
        address pool;
        uint256 bptAmount;
        IERC20[] tokens;
        uint256[] amountsOut;
        bytes userData;
    }

    struct BalancerExtraParams {
        address pool;
        IERC20[] tokens;
    }

    IVault public vault;

    function initialize(IVault _vault) public virtual initializer {
        Errors.verifyNotZero(address(_vault), "_vault");
        vault = _vault;
    }

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minLpMintAmount,
        bytes calldata extraParams
    ) public nonReentrant {
        (BalancerExtraParams memory balancerExtraParams) = abi.decode(extraParams, (BalancerExtraParams));
        if (balancerExtraParams.tokens.length == 0 || balancerExtraParams.tokens.length != amounts.length) {
            revert ArraysLengthMismatch();
        }
        if (minLpMintAmount == 0) {
            revert MustBeMoreThanZero();
        }
        Errors.verifyNotZero(balancerExtraParams.pool, "balancerExtraParams.pool");
        // bytes32 poolId = IBalancerPool(balancerExtraParams.pool).getPoolId();

        uint256[] memory assetBalancesBefore = new uint256[](balancerExtraParams.tokens.length);

        // verify that we're passing correct pool tokens
        _ensureTokenOrderAndApprovals(
            amounts, balancerExtraParams.tokens, IBalancerPool(balancerExtraParams.pool), assetBalancesBefore
        );

        // record balances before deposit
        uint256 bptBalanceBefore = IERC20(balancerExtraParams.pool).balanceOf(address(this));

        vault.joinPool(
            IBalancerPool(balancerExtraParams.pool).getPoolId(),
            address(this), // sender
            address(this), // recipient of BPT token
            _getJoinPoolRequest(
                IBalancerPool(balancerExtraParams.pool), balancerExtraParams.tokens, amounts, minLpMintAmount
            )
        );

        // make sure we received bpt
        uint256 bptBalanceAfter = IERC20(balancerExtraParams.pool).balanceOf(address(this));
        if (bptBalanceAfter < bptBalanceBefore + minLpMintAmount) {
            revert BalanceMustIncrease();
        }
        // make sure we spent exactly how much we wanted
        for (uint256 i = 0; i < balancerExtraParams.tokens.length; ++i) {
            //slither-disable-next-line calls-loop
            uint256 currentBalance = balancerExtraParams.tokens[i].balanceOf(address(this));

            if (currentBalance != assetBalancesBefore[i] - amounts[i]) {
                // For composable pools it might be a case that we deposit 0 LP tokens and our LP balance increases
                if (address(balancerExtraParams.tokens[i]) != address(balancerExtraParams.pool)) {
                    revert InvalidBalanceChange();
                }
            }
        }

        emit DeployLiquidity(
            amounts,
            _convertERC20sToAddresses(balancerExtraParams.tokens),
            [bptBalanceAfter - bptBalanceBefore, bptBalanceAfter, IERC20(balancerExtraParams.pool).totalSupply()],
            balancerExtraParams.pool,
            IBalancerPool(balancerExtraParams.pool).getPoolId()
        );
    }

    function removeLiquidity(
        uint256[] calldata amounts,
        uint256 maxLpBurnAmount,
        bytes calldata extraParams
    ) public nonReentrant returns (uint256[] memory actualAmounts) {
        (BalancerExtraParams memory balancerExtraParams) = abi.decode(extraParams, (BalancerExtraParams));
        // encode withdraw request
        bytes memory userData = abi.encode(ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT, amounts, maxLpBurnAmount);

        actualAmounts = _withdraw(
            WithdrawParams({
                pool: balancerExtraParams.pool,
                bptAmount: maxLpBurnAmount,
                tokens: balancerExtraParams.tokens,
                amountsOut: amounts,
                userData: userData
            })
        );
    }

    /// @notice Withdraw liquidity from Balancer V2 pool (specifying exact LP tokens to burn)
    /// @dev Calls into external contract
    /// @param pool Balancer Pool to liquidity withdrawn from
    /// @param poolAmountIn Amount of LP tokens to burn in the withdrawal
    /// @param minAmountsOut Array of minimum amounts of tokens to be withdrawn from pool
    function removeLiquidityImbalance(
        address pool,
        uint256 poolAmountIn,
        IERC20[] memory tokens,
        uint256[] memory minAmountsOut
    ) public nonReentrant returns (uint256[] memory withdrawnAmounts) {
        // encode withdraw request
        bytes memory userData = abi.encode(ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, poolAmountIn);

        withdrawnAmounts = _withdraw(
            WithdrawParams({
                pool: pool,
                bptAmount: poolAmountIn,
                tokens: tokens,
                amountsOut: minAmountsOut,
                userData: userData
            })
        );
    }

    function _withdraw(WithdrawParams memory params) private returns (uint256[] memory amountsOut) {
        Errors.verifyNotZero(params.pool, "params.pool");
        // slither-disable-next-line incorrect-equality
        if (params.bptAmount == 0) revert MustBeMoreThanZero();

        amountsOut = params.amountsOut;

        uint256 nTokens = params.tokens.length;
        // slither-disable-next-line incorrect-equality
        if (nTokens == 0 || nTokens != amountsOut.length) {
            revert ArraysLengthMismatch();
        }

        bytes32 poolId = IBalancerPool(params.pool).getPoolId();
        (IERC20[] memory poolTokens,,) = vault.getPoolTokens(poolId);

        if (poolTokens.length != nTokens) {
            revert ArraysLengthMismatch();
        }

        _checkZeroBalancesWithdrawal(params.tokens, poolTokens, amountsOut);

        // grant erc20 approval for vault to spend our tokens
        LibAdapter._approve(IERC20(params.pool), address(vault), params.bptAmount);

        // record balance before withdraw
        uint256 bptBalanceBefore = IERC20(params.pool).balanceOf(address(this));

        uint256[] memory assetBalancesBefore = new uint256[](nTokens);
        for (uint256 i = 0; i < nTokens; ++i) {
            assetBalancesBefore[i] = poolTokens[i].balanceOf(address(this));
        }

        // As we're exiting the pool we need to make an ExitPoolRequest instead
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: _convertERC20sToAssets(poolTokens),
            minAmountsOut: amountsOut,
            userData: params.userData,
            toInternalBalance: false
        });

        vault.exitPool(
            poolId,
            address(this), // sender,
            payable(address(this)), // recipient,
            request
        );

        // make sure we burned bpt, and assets were received
        uint256 bptBalanceAfter = IERC20(params.pool).balanceOf(address(this));
        if (bptBalanceAfter >= bptBalanceBefore) {
            revert InvalidBalanceChange();
        }

        for (uint256 i = 0; i < nTokens; ++i) {
            uint256 assetBalanceBefore = assetBalancesBefore[i];

            uint256 currentBalance = poolTokens[i].balanceOf(address(this));

            if (currentBalance < assetBalanceBefore + amountsOut[i]) {
                revert BalanceMustIncrease();
            }
            // Get actual amount returned for event, reuse amountsOut array
            amountsOut[i] = currentBalance - assetBalanceBefore;
        }

        emit WithdrawLiquidity(
            amountsOut,
            _convertERC20sToAddresses(params.tokens),
            [bptBalanceBefore - bptBalanceAfter, bptBalanceAfter, IERC20(params.pool).totalSupply()],
            params.pool,
            poolId
        );
    }

    /**
     * @dev This helper function is a fast and cheap way to convert between IERC20[] and IAsset[] types
     */
    function _convertERC20sToAssets(IERC20[] memory tokens) internal pure returns (IAsset[] memory assets) {
        //slither-disable-start assembly
        //solhint-disable-next-line no-inline-assembly
        assembly {
            assets := tokens
        }
        //slither-disable-end assembly
    }

    function _convertERC20sToAddresses(IERC20[] memory tokens)
        internal
        pure
        returns (address[] memory tokenAddresses)
    {
        tokenAddresses = new address[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            tokenAddresses[i] = address(tokens[i]);
        }
    }

    // run through tokens and make sure it matches the pool's assets, check non zero amount
    function _checkZeroBalancesWithdrawal(
        IERC20[] memory tokens,
        IERC20[] memory poolTokens,
        uint256[] memory amountsOut
    ) private pure {
        bool hasNonZeroAmount = false;
        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 currentToken = tokens[i];
            if (currentToken != poolTokens[i]) {
                revert TokenPoolAssetMismatch();
            }
            if (!hasNonZeroAmount && amountsOut[i] > 0) {
                hasNonZeroAmount = true;
            }
        }
        if (!hasNonZeroAmount) revert NoNonZeroAmountProvided();
    }

    /// @notice Validate that given tokens are relying to the given pool and approve spend
    /// @dev Separate function to avoid stack-too-deep errors
    ///      and combine gas-costly loop operations into single loop
    /// @param amounts Amounts of corresponding tokens to approve
    /// @param pool Balancer Pool to pull token information from
    /// @param assetBalancesBefore Array to record initial token balances
    function _ensureTokenOrderAndApprovals(
        uint256[] calldata amounts,
        IERC20[] memory tokens,
        IBalancerPool pool,
        uint256[] memory assetBalancesBefore
    ) private {
        // (two part verification: total number checked here, and individual match check below)
        (IERC20[] memory poolAssets,,) = vault.getPoolTokens(pool.getPoolId());

        uint256 nTokens = amounts.length;

        if (poolAssets.length != nTokens) {
            revert ArraysLengthMismatch();
        }

        // run through tokens and make sure we have approvals (and correct token order)
        for (uint256 i = 0; i < nTokens; ++i) {
            uint256 currentAmount = amounts[i];
            IERC20 currentToken = tokens[i];

            // as per new requirements, 0 amounts are not allowed even though balancer supports it
            // LP token is an exception for composable pools
            if (currentAmount == 0 && address(currentToken) != address(pool)) {
                revert MustBeMoreThanZero();
            }
            // make sure asset is supported (and matches the pool's assets)
            if (currentToken != poolAssets[i]) {
                revert TokenPoolAssetMismatch();
            }

            // record previous balance for this asset
            assetBalancesBefore[i] = currentToken.balanceOf(address(this));

            // grant spending approval to balancer's Vault
            LibAdapter._approve(IERC20(currentToken), address(vault), currentAmount);
        }
    }

    /// @notice Generate request for Balancer's Vault to join the pool
    /// @dev Separate function to avoid stack-too-deep errors
    /// @param tokens Tokens to be deposited into pool
    /// @param amounts Amounts of corresponding tokens to deposit
    /// @param poolAmountOut Expected amount of LP tokens to be minted on deposit
    function _getJoinPoolRequest(
        IBalancerPool pool,
        IERC20[] memory tokens,
        uint256[] calldata amounts,
        uint256 poolAmountOut
    ) private view returns (IVault.JoinPoolRequest memory joinRequest) {
        joinRequest = IVault.JoinPoolRequest({
            assets: _convertERC20sToAssets(tokens),
            maxAmountsIn: amounts, // maxAmountsIn,
            userData: abi.encode(
                JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
                _getUserAmounts(pool, amounts), //maxAmountsIn,
                poolAmountOut
                ),
            fromInternalBalance: false
        });
    }

    function _getUserAmounts(
        IBalancerPool pool,
        uint256[] calldata amounts
    ) private view returns (uint256[] memory userAmounts) {
        // Using the presence of a getBptIndex() fn as an indicator of pool type
        // slither-disable-next-line low-level-calls
        (bool success, bytes memory data) = address(pool).staticcall(abi.encodeWithSignature("getBptIndex()"));

        if (success) {
            userAmounts = new uint256[](amounts.length-1);
            uint256 bptIndex = abi.decode(data, (uint256));
            uint256 userAmountsIndex = 0;
            for (uint256 i = 0; i < amounts.length; ++i) {
                if (i == bptIndex) {
                    continue;
                }
                userAmounts[userAmountsIndex] = amounts[i];
                userAmountsIndex++;
            }
        } else {
            userAmounts = amounts;
        }
    }
}
