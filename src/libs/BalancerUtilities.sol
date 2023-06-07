// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { IVault } from "src/interfaces/external/balancer/IVault.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { LibAdapter } from "src/libs/LibAdapter.sol";

import { IBalancerComposableStablePool } from "src/interfaces/external/balancer/IBalancerComposableStablePool.sol";

library BalancerUtilities {
    error BalancerVaultReentrancy();

    struct BalancerExtraParams {
        address pool;
        IERC20[] tokens;
    }
    // 400 is Balancers Vault REENTRANCY error code

    bytes32 internal constant REENTRANCY_ERROR_HASH = keccak256(abi.encodeWithSignature("Error(string)", "BAL#400"));

    function checkReentrancy(address balancerVault) external view {
        // Reentrancy protection
        // solhint-disable max-line-length
        // https://github.com/balancer/balancer-v2-monorepo/blob/90f77293fef4b8782feae68643c745c754bac45c/pkg/pool-utils/contracts/lib/VaultReentrancyLib.sol
        (, bytes memory returnData) = balancerVault.staticcall(
            abi.encodeWithSelector(IVault.manageUserBalance.selector, new IVault.UserBalanceOp[](0))
        );
        if (keccak256(returnData) == REENTRANCY_ERROR_HASH) {
            revert BalancerVaultReentrancy();
        }
    }

    error MustBeMoreThanZero();
    error ArraysLengthMismatch();
    error BalanceMustIncrease();
    error MinLpAmountNotReached();
    error LpTokenAmountMismatch();
    error NoNonZeroAmountProvided();
    error InvalidBalanceChange();
    error InvalidAddress(address);

    enum ExitKind {
        EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
        BPT_IN_FOR_EXACT_TOKENS_OUT,
        EXACT_BPT_IN_FOR_ALL_TOKENS_OUT
    }

    function removeLiquidityComposableExactLP(
        IVault balancerVault,
        address pool,
        uint256 exactLpBurnAmount,
        address[] memory tokens,
        uint256[] calldata minAmounts
    ) external returns (uint256[] memory actualAmounts) {
        // enum ExitKind {
        //      EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
        //      BPT_IN_FOR_EXACT_TOKENS_OUT,
        //      EXACT_BPT_IN_FOR_ALL_TOKENS_OUT
        // }
        uint256 exitKind = 2;
        bytes memory userData = abi.encode(exitKind, exactLpBurnAmount);

        LibAdapter._approve(IERC20(pool), address(balancerVault), exactLpBurnAmount);

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: tokens,
            minAmountsOut: minAmounts,
            userData: userData,
            toInternalBalance: false
        });

        balancerVault.exitPool(
            IBalancerComposableStablePool(pool).getPoolId(),
            address(this), // sender,
            payable(address(this)), // recipient,
            request
        );
    }

    function removeLiquidityComposableImbalance(
        IVault balancerVault,
        address pool,
        uint256 exactLpBurnAmount,
        uint256 exitTokenIndex,
        address[] memory tokens,
        uint256[] calldata minAmounts
    ) external returns (uint256[] memory actualAmounts) {
        bytes memory userData = abi.encode(ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, exactLpBurnAmount, exitTokenIndex);

        LibAdapter._approve(IERC20(pool), address(balancerVault), exactLpBurnAmount);

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: tokens,
            minAmountsOut: minAmounts,
            userData: userData,
            toInternalBalance: false
        });

        balancerVault.exitPool(
            IBalancerComposableStablePool(pool).getPoolId(),
            address(this), // sender,
            payable(address(this)), // recipient,
            request
        );
    }

    function addLiquidityComposable(
        IVault vault,
        address pool,
        address[] memory tokens,
        uint256[] calldata exactTokenAmounts,
        uint256 minLpMintAmount
    ) public {
        // Approve the underlying pool tokens
        // While building our user amounts array that filters out the
        // the amount of the bpt token
        uint256 nTokens = tokens.length;
        uint256 uix = 0;
        uint256 bptIndex = IBalancerComposableStablePool(pool).getBptIndex();
        uint256[] memory amountsUser = new uint256[](nTokens - 1);
        for (uint256 i = 0; i < nTokens; i++) {
            if (i != bptIndex) {
                LibAdapter._approve(tokens[i], address(vault), exactTokenAmounts[i]);
                amountsUser[uix] = exactTokenAmounts[i];
                uix++;
            }
        }

        IVault.JoinPoolRequest memory joinRequest = IVault.JoinPoolRequest({
            assets: tokens,
            maxAmountsIn: exactTokenAmounts, // maxAmountsIn,
            userData: abi.encode(IVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amountsUser, minLpMintAmount),
            fromInternalBalance: false
        });

        vault.joinPool(
            IBalancerComposableStablePool(pool).getPoolId(),
            address(this), // sender
            address(this), // recipient of BPT token
            joinRequest
        );
    }

    function isComposablePool(address pool) public view returns (bool) {
        // Using the presence of a getBptIndex() fn as an indicator of pool type
        // slither-disable-start low-level-calls
        // solhint-disable-next-line no-unused-vars
        (bool success, bytes memory data) = pool.staticcall(abi.encodeWithSignature("getBptIndex()"));
        // slither-disable-end low-level-calls
        return success;
    }

    /**
     * @dev This helper function is a fast and cheap way to convert between IERC20[] and IAsset[] types
     */
    function _convertERC20sToAddresses(IERC20[] memory tokens) internal pure returns (address[] memory assets) {
        //slither-disable-start assembly
        //solhint-disable-next-line no-inline-assembly
        assembly {
            assets := tokens
        }
        //slither-disable-end assembly
    }
}
