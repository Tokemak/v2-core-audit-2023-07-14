// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import { IPlasmaPoolClaimableRewards } from "../interfaces/rewards/IPlasmaPoolClaimableRewards.sol";
import { ILiquidable, SwapperParams } from "../interfaces/liquidators/ILiquidable.sol";
import { ILiquidator } from "../interfaces/liquidators/ILiquidator.sol";

contract Liquidator is ILiquidator, ReentrancyGuard {
    /**
     * @notice Claim rewards from a list of vaults
     * @param vaults The list of vaults to claim rewards from
     */
    function claimsVaultRewards(IPlasmaPoolClaimableRewards[] memory vaults) public nonReentrant {
        for (uint256 i = 0; i < vaults.length; i++) {
            if (address(vaults[i]) == address(0)) revert ZeroAddress();
            IPlasmaPoolClaimableRewards vault = vaults[i];
            vault.claimRewards();
        }
    }

    /**
     * @notice Liquidate a list of vaults
     * @param vaults The list of vaults to liquidate
     * @param swapperParamsList The list of swapper params to use for each vault
     */
    function liquidateVaults(
        ILiquidable[] memory vaults,
        SwapperParams[] memory swapperParamsList
    ) public nonReentrant {
        if (vaults.length != swapperParamsList.length) revert InvalidParamsLength();

        for (uint256 i = 0; i < vaults.length; i++) {
            if (address(vaults[i]) == address(0)) revert ZeroAddress();

            ILiquidable vault = vaults[i];
            SwapperParams memory swapperParams = swapperParamsList[i];

            vault.liquidate(swapperParams);
        }
    }
}
