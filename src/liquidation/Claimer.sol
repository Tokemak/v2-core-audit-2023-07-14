// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import { IVaultClaimableRewards } from "../interfaces/rewards/IVaultClaimableRewards.sol";
import { IClaimer } from "../interfaces/liquidation/IClaimer.sol";

contract Claimer is IClaimer, ReentrancyGuard {
    /**
     * @notice Claim rewards from a list of vaults
     * @param vaults The list of vaults to claim rewards from
     */
    function claimsVaultRewards(IVaultClaimableRewards[] memory vaults) public nonReentrant {
        for (uint256 i = 0; i < vaults.length; i++) {
            if (address(vaults[i]) == address(0)) revert ZeroAddress();
            IVaultClaimableRewards vault = vaults[i];
            // slither-disable-next-line unused-return,calls-loop
            vault.claimRewards();
        }
    }
}
