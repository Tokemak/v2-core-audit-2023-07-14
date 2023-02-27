// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/access/AccessControl.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IDestinationAdapter } from "../../interfaces/destinations/IDestinationAdapter.sol";
import { IAsset } from "../../interfaces/external/balancer/IAsset.sol";
import { IVault } from "../../interfaces/external/balancer/IVault.sol";
import { LibAdapter } from "./libs/LibAdapter.sol";

contract BalancerV2MetaStablePoolAdapter is IDestinationAdapter, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

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

    /// @param poolId bytes32 Balancer poolId
    /// @param bptAmount uint256 pool token amount expected back
    /// @param tokens IERC20[] of tokens to be withdrawn from pool
    /// @param amountsOut uint256[] min amount of tokens expected on withdrawal
    /// @param userData bytes data, used for info about kind of pool exit
    struct WithdrawParams {
        bytes32 poolId;
        uint256 bptAmount;
        IERC20[] tokens;
        uint256[] amountsOut;
        bytes userData;
    }

    struct BalancerExtraParams {
        bytes32 poolId;
        IERC20[] tokens;
    }

    IVault public immutable vault;

    constructor(IVault _vault) {
        require(address(_vault) != address(0), "!vault");

        vault = _vault;
    }

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minLpMintAmount,
        bytes calldata extraParams
    )
        external
        nonReentrant
    {
        (BalancerExtraParams memory balancerExtraParams) = abi.decode(extraParams, (BalancerExtraParams));
        if (balancerExtraParams.tokens.length != amounts.length) {
            revert("Array length mismatch");
        }
        if (balancerExtraParams.tokens.length == 0 || minLpMintAmount == 0) {
            revert("Must not be 0");
        }

        // get bpt address of the pool (for later balance checks)
        (address poolAddress,) = vault.getPool(balancerExtraParams.poolId);

        uint256[] memory assetBalancesBefore = new uint256[](balancerExtraParams.tokens.length);

        // verify that we're passing correct pool tokens
        _ensureTokenOrderAndApprovals(
            balancerExtraParams.tokens.length,
            amounts,
            balancerExtraParams.tokens,
            balancerExtraParams.poolId,
            assetBalancesBefore
        );

        // record balances before deposit
        uint256 bptBalanceBefore = IERC20(poolAddress).balanceOf(address(this));

        vault.joinPool(
            balancerExtraParams.poolId,
            address(this), // sender
            address(this), // recipient of BPT token
            _getJoinPoolRequest(balancerExtraParams.tokens, amounts, minLpMintAmount)
        );

        // make sure we received bpt
        uint256 bptBalanceAfter = IERC20(poolAddress).balanceOf(address(this));
        if (bptBalanceAfter < bptBalanceBefore + minLpMintAmount) {
            revert("LP balance must increase");
        }
        // make sure assets were taken out
        for (uint256 i = 0; i < balancerExtraParams.tokens.length;) {
            //slither-disable-next-line calls-loop
            uint256 currentBalance = balancerExtraParams.tokens[i].balanceOf(address(this));
            if (currentBalance != assetBalancesBefore[i] - amounts[i]) {
                revert("Token balance must increase");
            }
            unchecked {
                ++i;
            }
        }

        _emitDepositEvent(
            amounts,
            _convertERC20sToAddresses(balancerExtraParams.tokens),
            [bptBalanceAfter - bptBalanceBefore, bptBalanceAfter, IERC20(poolAddress).totalSupply()],
            poolAddress,
            balancerExtraParams.poolId
        );
    }

    function removeLiquidity(
        uint256[] calldata amounts,
        uint256 maxLpBurnAmount,
        bytes calldata extraParams
    )
        external
        nonReentrant
    {
        (BalancerExtraParams memory balancerExtraParams) = abi.decode(extraParams, (BalancerExtraParams));
        // encode withdraw request
        bytes memory userData = abi.encode(ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT, amounts, maxLpBurnAmount);

        _withdraw(
            WithdrawParams({
                poolId: balancerExtraParams.poolId,
                bptAmount: maxLpBurnAmount,
                tokens: balancerExtraParams.tokens,
                amountsOut: amounts,
                userData: userData
            })
        );
    }

    /// @notice Withdraw liquidity from Balancer V2 pool (specifying exact LP tokens to burn)
    /// @dev Calls into external contract
    /// @param poolId Balancer's ID of the pool to have liquidity withdrawn from
    /// @param poolAmountIn Amount of LP tokens to burn in the withdrawal
    /// @param minAmountsOut Array of minimum amounts of tokens to be withdrawn from pool
    function removeLiquidityImbalance(
        bytes32 poolId,
        uint256 poolAmountIn,
        IERC20[] calldata tokens,
        uint256[] calldata minAmountsOut
    )
        external
        nonReentrant
    {
        // encode withdraw request
        bytes memory userData = abi.encode(ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, poolAmountIn);

        _withdraw(
            WithdrawParams({
                poolId: poolId,
                bptAmount: poolAmountIn,
                tokens: tokens,
                amountsOut: minAmountsOut,
                userData: userData
            })
        );
    }

    function _withdraw(WithdrawParams memory params) private {
        uint256[] memory amountsOut = params.amountsOut;
        bytes32 poolId = params.poolId;

        uint256 nTokens = params.tokens.length;
        uint256 amountsOutLen = amountsOut.length;
        if (nTokens != amountsOutLen) {
            revert("Array length mismatch");
        }
        if (nTokens == 0) revert("nTokens must be > 0");

        (IERC20[] memory poolTokens,,) = vault.getPoolTokens(poolId);
        uint256 numTokens = poolTokens.length;

        if (numTokens != amountsOutLen) {
            revert("Array length mismatch");
        }

        checkZeroBalancesWithdrawal(params.tokens, poolTokens, amountsOut);

        // grant erc20 approval for vault to spend our tokens
        (address poolAddress,) = vault.getPool(poolId);
        LibAdapter._approve(IERC20(poolAddress), address(vault), params.bptAmount);

        // record balance before withdraw
        uint256 bptBalanceBefore = IERC20(poolAddress).balanceOf(address(this));
        uint256[] memory assetBalancesBefore = new uint256[](poolTokens.length);
        for (uint256 i = 0; i < numTokens;) {
            assetBalancesBefore[i] = poolTokens[i].balanceOf(address(this));
            unchecked {
                ++i;
            }
        }

        // As we're exiting the pool we need to make an ExitPoolRequest instead
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: _convertERC20sToAssets(poolTokens),
            minAmountsOut: amountsOut,
            userData: params.userData,
            toInternalBalance: false // send tokens back to us vs keeping inside vault for later use
         });

        vault.exitPool(
            poolId,
            address(this), // sender,
            payable(address(this)), // recipient,
            request
        );

        // make sure we burned bpt, and assets were received
        uint256 bptBalanceAfter = IERC20(poolAddress).balanceOf(address(this));
        if (bptBalanceAfter >= bptBalanceBefore) {
            revert("Balancer must decrease");
        }

        for (uint256 i = 0; i < numTokens;) {
            uint256 currentAmount = amountsOut[i];
            uint256 currentAssetBalanceBefore = assetBalancesBefore[i];

            uint256 currentTokenCurrentBalance = poolTokens[i].balanceOf(address(this));

            if (currentTokenCurrentBalance < currentAssetBalanceBefore + currentAmount) {
                revert("Balance must increase");
            }
            // Get actual amount returned for event, reuse amountsOut array
            currentAmount = currentTokenCurrentBalance - currentAssetBalanceBefore;
            unchecked {
                ++i;
            }
        }

        _emitWithdrawEvent(
            amountsOut,
            _convertERC20sToAddresses(params.tokens),
            [bptBalanceBefore - bptBalanceAfter, bptBalanceAfter, IERC20(poolAddress).totalSupply()],
            poolAddress,
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
        for (uint256 i = 0; i < tokens.length;) {
            tokenAddresses[i] = address(tokens[i]);
            unchecked {
                ++i;
            }
        }
    }

    // run through tokens and make sure it matches the pool's assets, check non zero amount
    function checkZeroBalancesWithdrawal(
        IERC20[] memory tokens,
        IERC20[] memory poolTokens,
        uint256[] memory amountsOut
    )
        private
        pure
    {
        bool hasNonZeroAmount = false;
        for (uint256 i = 0; i < tokens.length;) {
            IERC20 currentToken = tokens[i];
            // _validateToken(currentToken); TODO: Call to Token Registry
            if (currentToken != poolTokens[i]) {
                revert("Token pool asset mismatch");
            }
            if (!hasNonZeroAmount && amountsOut[i] > 0) {
                hasNonZeroAmount = true;
            }
            unchecked {
                ++i;
            }
        }
        if (!hasNonZeroAmount) revert("No non-zero amount provided");
    }

    /// @dev Separate function to avoid stack-too-deep errors
    function _ensureTokenOrderAndApprovals(
        uint256 nTokens,
        uint256[] calldata amounts,
        IERC20[] memory tokens,
        bytes32 poolId,
        uint256[] memory assetBalancesBefore
    )
        private
    {
        // (two part verification: total number checked here, and individual match check below)
        (IERC20[] memory poolAssets,,) = vault.getPoolTokens(poolId);

        if (poolAssets.length != nTokens) {
            revert("Array length mismatch");
        }

        // run through tokens and make sure we have approvals (and correct token order)
        for (uint256 i = 0; i < nTokens;) {
            uint256 currentAmount = amounts[i];
            IERC20 currentToken = tokens[i];

            // as per new requirements, 0 amounts are not allowed even though balancer supports it
            if (currentAmount == 0) {
                revert("currentAmount must be > 0");
            }
            // make sure asset is supported (and matches the pool's assets)
            // _validateToken(currentToken); TODO: Call to Token Registry

            if (currentToken != poolAssets[i]) {
                revert("Token pool asset mismatch");
            }

            // record previous balance for this asset
            assetBalancesBefore[i] = currentToken.balanceOf(address(this));

            // grant spending approval to balancer's Vault
            LibAdapter._approve(IERC20(currentToken), address(vault), currentAmount);

            unchecked {
                ++i;
            }
        }
    }

    function _getJoinPoolRequest(
        IERC20[] memory tokens,
        uint256[] calldata amounts,
        uint256 poolAmountOut
    )
        private
        pure
        returns (IVault.JoinPoolRequest memory joinRequest)
    {
        joinRequest = IVault.JoinPoolRequest({
            assets: _convertERC20sToAssets(tokens),
            maxAmountsIn: amounts, // maxAmountsIn,
            userData: abi.encode(
                JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
                amounts, //maxAmountsIn,
                poolAmountOut
                ),
            fromInternalBalance: false // vault will pull the tokens from diamond instead of internal balances
         });
    }

    /// @dev Separate function to avoid stack-too-deep errors
    function _emitDepositEvent(
        uint256[] memory amounts,
        address[] memory tokens,
        uint256[3] memory lpAmounts,
        address poolAddress,
        bytes32 poolId
    )
        private
    {
        bytes memory extraData = abi.encode(poolAddress, poolId);
        emit DeployLiquidity(amounts, tokens, lpAmounts[0], lpAmounts[1], lpAmounts[2], extraData);
    }

    /// @dev Separate function to avoid stack-too-deep errors
    function _emitWithdrawEvent(
        uint256[] memory amounts,
        address[] memory tokens,
        uint256[3] memory lpAmounts,
        address poolAddress,
        bytes32 poolId
    )
        private
    {
        emit WithdrawLiquidity(
            amounts, tokens, lpAmounts[0], lpAmounts[1], lpAmounts[2], abi.encode(poolAddress, poolId)
            );
    }
}
