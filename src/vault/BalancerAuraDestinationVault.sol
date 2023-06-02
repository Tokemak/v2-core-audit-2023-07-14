// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { Math } from "openzeppelin-contracts/utils/math/Math.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { DestinationVault } from "src/vault/DestinationVault.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { MainRewarder } from "src/rewarders/MainRewarder.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import { BalancerV2LPValueProvider } from "src/pricing/value-providers/BalancerV2LPValueProvider.sol";
import { IVault } from "src/interfaces/external/balancer/IVault.sol";
import { IBalancerPool } from "src/interfaces/external/balancer/IBalancerPool.sol";
import { AuraAdapter } from "src/destinations/adapters/staking/AuraAdapter.sol";
import { BalancerV2MetaStablePoolAdapter } from "src/destinations/adapters/BalancerV2MetaStablePoolAdapter.sol";

contract BalancerAuraDestinationVault is AuraAdapter, BalancerV2MetaStablePoolAdapter, DestinationVault {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    error NothingToClaim();
    error NoDebtReclaimed();

    /* ******************************** */
    /* State Variables                  */
    /* ******************************** */

    MainRewarder public rewarder;
    ISwapRouter public swapper;
    BalancerV2LPValueProvider public pricingProvider;

    IERC20[] public poolTokens;

    address public staking;
    address public pool;

    function initialize(
        ISystemRegistry _systemRegistry,
        IERC20Metadata _baseAsset,
        string memory baseName,
        bytes memory data,
        IVault _vault,
        MainRewarder _rewarder,
        ISwapRouter _swapper,
        BalancerV2LPValueProvider _pricingProvider,
        address _staking,
        address _pool
    ) public initializer {
        //slither-disable-start missing-zero-check
        DestinationVault.initialize(_systemRegistry, _baseAsset, baseName, data);
        BalancerV2MetaStablePoolAdapter.initialize(_vault);

        Errors.verifyNotZero(address(_rewarder), "_rewarder");
        Errors.verifyNotZero(address(_swapper), "_swapper");
        Errors.verifyNotZero(address(_staking), "_staking");
        Errors.verifyNotZero(address(_pricingProvider), "_pricingProvider");
        Errors.verifyNotZero(address(_pool), "_pool");

        rewarder = _rewarder;
        swapper = _swapper;
        pricingProvider = _pricingProvider;
        staking = _staking;
        pool = _pool;

        bytes32 poolId = IBalancerPool(pool).getPoolId();
        (IERC20[] memory balancerPoolTokens,,) = vault.getPoolTokens(poolId);
        if (balancerPoolTokens.length == 0) revert ArrayLengthMismatch();
        poolTokens = balancerPoolTokens;

        //slither-disable-next-line unused-return
        trackedTokens.add(_pool);

        for (uint256 i = 0; i < balancerPoolTokens.length; ++i) {
            //slither-disable-next-line unused-return
            trackedTokens.add(address(balancerPoolTokens[i]));
        }
        //slither-disable-end missing-zero-check
    }

    function auraBalance() public view returns (uint256) {
        return IERC20(staking).balanceOf(address(this));
    }

    function balancerBalance() public view returns (uint256) {
        return IERC20(pool).balanceOf(address(this));
    }

    function totalLpAmount() public view returns (uint256) {
        return auraBalance() + balancerBalance();
    }

    function debtValue() public view override returns (uint256 value) {
        uint256 auraLPBalance = auraBalance();
        uint256 balancerLpAmount = balancerBalance();
        value = (auraLPBalance + balancerLpAmount) * pricingProvider.getPrice(pool);
    }

    function rewardValue() public view override returns (uint256 value) {
        value = rewarder.earned(address(this));

        //slither-disable-start calls-loop
        for (uint256 i = 0; i < rewarder.extraRewardsLength(); ++i) {
            IERC20 rewardToken = IERC20(rewarder.extraRewards(i));
            uint256 rewardAmount = rewardToken.balanceOf(address(this));
            uint256 rewardPrice = rewardAmount * pricingProvider.getPrice(address(rewardToken));
            value += rewardPrice;
        }
        //slither-disable-end calls-loop
    }

    function claimVested_() internal virtual override nonReentrant returns (uint256 amount) {
        uint256 balanceBefore = baseAsset.balanceOf(address(this));
        rewarder.getReward();
        amount = baseAsset.balanceOf(address(this)) - balanceBefore;
        // slither-disable-next-line incorrect-equality
        if (amount == 0) revert NothingToClaim();
    }

    function reclaimDebt_(
        uint256 pctNumerator,
        uint256 pctDenominator
    ) internal virtual override nonReentrant returns (uint256 amount, uint256 loss) {
        // defining total amount we want to burn in base asset value
        uint256 totalBurnAmount = Math.mulDiv(debt, pctNumerator, pctDenominator, Math.Rounding.Down);
        // defining total amount we want to burn in terms of LP quantity
        uint256 totalLpBurnAmount = Math.mulDiv(totalLpAmount(), pctNumerator, pctDenominator, Math.Rounding.Down);

        // 1) withdraw Aura if we cannot cover all (we prefer not to pull Aura to stake as long as we can)
        uint256 auraLpBurnAmount = 0;
        uint256 balancerLpBalance = balancerBalance();
        if (totalLpBurnAmount > balancerLpBalance) {
            auraLpBurnAmount = totalLpBurnAmount - balancerLpBalance;
            withdrawStake(pool, staking, auraLpBurnAmount);
        }

        // 2) withdraw Balancer
        // all minAmounts are 0, we set the burn LP amount and don't specify the amounts we expect by each token
        uint256[] memory minAmounts = new uint256[](poolTokens.length);
        uint256[] memory sellAmounts =
            removeLiquidityImbalance(address(pool), totalLpBurnAmount, poolTokens, minAmounts);

        // 3) swap what we receive
        for (uint256 i = 0; i < poolTokens.length; ++i) {
            uint256 sellAmount = sellAmounts[i];
            if (sellAmount != 0) {
                address sellToken = address(poolTokens[i]);
                IERC20(sellToken).safeApprove(address(swapper), sellAmount);
                amount += swapper.swapForQuote(sellToken, sellAmount, address(baseAsset), 0);
            }
        }

        // 4) check amount and loss
        // slither-disable-next-line incorrect-equality
        if (amount == 0) {
            revert NoDebtReclaimed();
        }
        if (amount < totalBurnAmount) {
            loss = totalBurnAmount - amount;
        }
    }
}