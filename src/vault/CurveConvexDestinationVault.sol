// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Math } from "openzeppelin-contracts/utils/math/Math.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import { DestinationVault } from "src/vault/DestinationVault.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { MainRewarder } from "src/rewarders/MainRewarder.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import { ConvexAdapter } from "src/destinations/adapters/staking/ConvexAdapter.sol";
import { CurveV2FactoryCryptoAdapter } from "src/destinations/adapters/CurveV2FactoryCryptoAdapter.sol";
import { Errors } from "src/utils/Errors.sol";

contract CurveConvexDestinationVault is ConvexAdapter, CurveV2FactoryCryptoAdapter, DestinationVault {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    error NothingToClaim();
    error NoDebtReclaimed();

    /* ******************************** */
    /* State Variables                  */
    /* ******************************** */

    MainRewarder public rewarder;
    ISwapRouter public swapper;

    IERC20 public lpToken;
    IERC20[] public poolTokens;

    address public staking;
    address public curvePool;

    ///@notice In `_trackedTokens` LP token must be at first position
    function initialize(
        ISystemRegistry _systemRegistry,
        IERC20Metadata _baseAsset,
        string memory baseName,
        bytes memory data,
        address payable _weth,
        MainRewarder _rewarder,
        ISwapRouter _swapper,
        address _staking,
        address _curvePool,
        IERC20 _lpToken,
        IERC20[] memory _poolTokens
    ) public initializer {
        //slither-disable-start missing-zero-check
        DestinationVault.initialize(_systemRegistry, _baseAsset, baseName, data);
        CurveV2FactoryCryptoAdapter.initialize(_weth);

        Errors.verifyNotZero(address(_rewarder), "_rewarder");
        Errors.verifyNotZero(address(_swapper), "_swapper");
        Errors.verifyNotZero(_staking, "_staking");
        Errors.verifyNotZero(_curvePool, "_curvePool");
        Errors.verifyNotZero(address(_lpToken), "_lpToken");

        rewarder = _rewarder;
        swapper = _swapper;
        staking = _staking;
        curvePool = _curvePool;
        lpToken = _lpToken;

        if (_poolTokens.length == 0) revert ArrayLengthMismatch();
        poolTokens = _poolTokens;

        //slither-disable-next-line unused-return
        trackedTokens.add(address(_lpToken));

        for (uint256 i = 0; i < poolTokens.length; ++i) {
            //slither-disable-next-line unused-return
            trackedTokens.add(address(poolTokens[i]));
        }
        //slither-disable-end missing-zero-check
    }

    function convexBalance() public view returns (uint256) {
        return IERC20(staking).balanceOf(address(this));
    }

    function curveBalance() public view returns (uint256) {
        return IERC20(lpToken).balanceOf(address(this));
    }

    function totalLpAmount() public view returns (uint256) {
        return convexBalance() + curveBalance();
    }

    function debtValue() public view override returns (uint256 value) {
        // solhint-disable-next-line no-unused-vars
        uint256 convexCurrentBalance = convexBalance();
        // solhint-disable-next-line no-unused-vars
        uint256 curveLpAmount = curveBalance();
        // TODO: integrate pricing:
        // value += lpAmountPrice;
    }

    function rewardValue() public view override returns (uint256 value) {
        value = rewarder.earned(address(this));

        //slither-disable-start calls-loop
        for (uint256 i = 0; i < rewarder.extraRewardsLength(); ++i) {
            IERC20 rewardToken = IERC20(rewarder.extraRewards(i));
            // solhint-disable-next-line no-unused-vars
            uint256 rewardAmount = rewardToken.balanceOf(address(this));
            // TODO: integrate pricing:
            // value += rewardPrice;
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

        // 1) withdraw Convex if we cannot cover all (we prefer not to pull Convex to stake as long as we can)
        uint256 convexLpBurnAmount = 0;
        uint256 curveLpBalance = curveBalance();
        if (totalLpBurnAmount > curveLpBalance) {
            convexLpBurnAmount = totalLpBurnAmount - curveLpBalance;
            withdrawStake(address(lpToken), staking, convexLpBurnAmount);
        }

        // 2) withdraw Curve
        uint256 curveLpBurnAmount = totalLpBurnAmount - convexLpBurnAmount;

        // using any coin with the 0-index so it's working for any-sized pools
        uint256 coinIndex = 0;

        // we withdraw everything in one coin to ease swapping
        (uint256 sellAmount, address sellToken) = removeLiquidityOneCoin(curvePool, curveLpBurnAmount, coinIndex, 0);

        // we should swap pre-wrapped WETH if pool is returning ETH
        // slither-disable-next-line incorrect-equality
        if (sellToken == CURVE_REGISTRY_ETH_ADDRESS_POINTER) {
            // get WETH address corresponding to the operated chain
            sellToken = address(weth);
        }

        // 3) swap what we receive
        // slither-disable-next-line incorrect-equality
        if (sellAmount == 0) {
            revert NoDebtReclaimed();
        }
        IERC20(sellToken).safeApprove(address(swapper), sellAmount);
        amount += swapper.swapForQuote(sellToken, sellAmount, address(baseAsset), 0);

        // 4) calculating the possible loss
        if (amount < totalBurnAmount) {
            loss = totalBurnAmount - amount;
        }
    }
}
