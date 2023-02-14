// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IBalancerPool, IERC20 } from "../../../interfaces/external/balancer/IBalancerPool.sol";
import { IVault } from "../../../interfaces/external/balancer/IVault.sol";

import { BaseValueProvider } from "../base/BaseValueProvider.sol";
import { TokemakPricingPrecision } from "../../library/TokemakPricingPrecision.sol";

/**
 * @title Base contract allowing for pricing of Balancer pools.
 * @author
 * @dev Returns 18 decimals of precision.
 */
abstract contract BaseValueProviderBalancerLP is BaseValueProvider {
    IVault public balancerVault;

    event BalancerVaultSet(address balancerVault);

    constructor(address _balancerVault, address _ethValueOracle) BaseValueProvider(_ethValueOracle) {
        setBalancerVault(_balancerVault);
    }

    /**
     * @dev Privileged access function.
     * @param _balancerVault Address of Vault.sol contract to set.
     */
    function setBalancerVault(address _balancerVault) public onlyOwner {
        if (_balancerVault == address(0)) revert CannotBeZeroAddress();
        balancerVault = IVault(_balancerVault);

        emit BalancerVaultSet(_balancerVault);
    }

    function _getPriceBalancerPool(address tokenToPrice) internal view virtual returns (uint256) {
        IBalancerPool pool = IBalancerPool(tokenToPrice);
        bytes32 poolId = pool.getPoolId();
        (IERC20[] memory tokens, uint256[] memory balances,) = balancerVault.getPoolTokens(poolId);

        uint256 poolValueEth;
        for (uint256 i = 0; i < tokens.length; ++i) {
            address currentToken = address(tokens[i]);

            // In case that pool lp token is stored in vault and returned on `getPoolTokens` call,
            //      skip iteration.  This is useful for ComposableStablePool and LinearPool contracts.
            if (currentToken == tokenToPrice) continue;

            // Get token decimals, normalize balance to 18 decimals if neccessary
            uint256 normalizedBalance = TokemakPricingPrecision.checkAndNormalizeDecimals(
                TokemakPricingPrecision.getDecimals(currentToken), balances[i]
            );

            poolValueEth += (
                ethValueOracle.getPrice(currentToken, TokemakPricingPrecision.STANDARD_PRECISION, true)
                    * normalizedBalance
            );
        }

        // Removes preminted bpt
        uint256 lpSupply = pool.totalSupply() - pool.balanceOf(address(balancerVault));
        uint256 normalizedLpSupply = TokemakPricingPrecision.checkAndNormalizeDecimals(pool.decimals(), lpSupply);

        return poolValueEth / normalizedLpSupply;
    }
}
