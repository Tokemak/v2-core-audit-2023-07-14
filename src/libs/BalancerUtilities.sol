// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { IVault } from "src/interfaces/external/balancer/IVault.sol";

library BalancerUtilities {
    error BalancerVaultReentrancy();

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
}
