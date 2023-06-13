// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Errors } from "src/utils/Errors.sol";
import { Math } from "openzeppelin-contracts/utils/math/Math.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { DestinationVault } from "src/vault/DestinationVault.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";
import { MainRewarder } from "src/rewarders/MainRewarder.sol";
import { ISwapRouter } from "src/interfaces/swapper/ISwapRouter.sol";
import { IRouter } from "src/interfaces/external/maverick/IRouter.sol";
import { IPool } from "src/interfaces/external/maverick/IPool.sol";
import { IPosition } from "src/interfaces/external/maverick/IPosition.sol";
import { IReward } from "src/interfaces/external/maverick/IReward.sol";
import { IPoolPositionSlim } from "src/interfaces/external/maverick/IPoolPositionSlim.sol";
import { MaverickStakingAdapter } from "src/destinations/adapters/staking/MaverickStakingAdapter.sol";

contract MaverickDestinationVault is DestinationVault, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    error NothingToClaim();
    error NoDebtReclaimed();

    /* ******************************** */
    /* State Variables                  */
    /* ******************************** */

    IPoolPositionSlim public boostedPosition;
    IReward public maverickRewarder;
    IPool public pool;
    IPosition public positionNft;
    IERC20 public stakingToken;

    function initialize(
        ISystemRegistry _systemRegistry,
        MainRewarder _rewarder,
        ISwapRouter _swapper,
        IERC20Metadata _baseAsset,
        string memory baseName,
        bytes memory data,
        IRouter maverickRouter,
        IPoolPositionSlim _boostedPosition,
        IReward _maverickRewarder,
        IPool _pool
    ) public initializer {
        //slither-disable-start missing-zero-check
        DestinationVault.initialize(_systemRegistry, _rewarder, _swapper, _baseAsset, baseName, data);

        Errors.verifyNotZero(address(_boostedPosition), "_boostedPosition");
        Errors.verifyNotZero(address(_maverickRewarder), "_maverickRewarder");
        Errors.verifyNotZero(address(_pool), "_pool");

        boostedPosition = _boostedPosition;
        maverickRewarder = _maverickRewarder;
        pool = _pool;
        positionNft = maverickRouter.position();
        stakingToken = IERC20(maverickRewarder.stakingToken());

        //slither-disable-start unused-return
        trackedTokens.add(address(stakingToken));
        trackedTokens.add(address(pool.tokenA()));
        trackedTokens.add(address(pool.tokenB()));
        //slither-disable-end unused-return

        //slither-disable-end missing-zero-check
    }

    function stakingTokenBalance() public view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }

    function stakedAmount() public view returns (uint256) {
        return maverickRewarder.balanceOf(address(this));
    }

    function totalLpAmount() public view returns (uint256) {
        return stakingTokenBalance() + stakedAmount();
    }

    function debtValue() public override returns (uint256 value) {
        value = totalLpAmount() * getTokenPriceInBaseAsset(address(stakingToken));
    }

    function rewardValue() public override returns (uint256 value) {
        value = rewarder.earned(address(this));

        //slither-disable-start calls-loop
        for (uint256 i = 0; i < rewarder.extraRewardsLength(); ++i) {
            address rewardToken = rewarder.extraRewards(i);
            uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(this));
            value += rewardAmount * getTokenPriceInBaseAsset(rewardToken);
        }
        //slither-disable-end calls-loop
    }

    /// @notice If base asset is not WETH (which is a case for our MVP)
    /// we should figure out price of the given token in terms of base asset
    function getTokenPriceInBaseAsset(address token) private returns (uint256 value) {
        //slither-disable-start calls-loop
        IRootPriceOracle priceOracle = systemRegistry.rootPriceOracle();
        uint256 tokenPriceInEth = priceOracle.getPriceInEth(token);
        if (keccak256(abi.encodePacked(baseAsset.symbol())) == keccak256(abi.encodePacked("WETH"))) {
            value = tokenPriceInEth;
        } else {
            uint256 baseAssetPriceInEth = priceOracle.getPriceInEth(address(baseAsset));
            value = tokenPriceInEth / baseAssetPriceInEth;
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

    /// @notice Stakes into Maverick Rewarder on deposit
    /// @dev Should be called by Strategy/Solver on liquidity deployment
    function stakeOnDeposit(uint256 amount) public {
        MaverickStakingAdapter.stakeLPs(maverickRewarder, amount);
    }

    function reclaimDebt_(
        uint256 pctNumerator,
        uint256 pctDenominator
    ) internal virtual override nonReentrant returns (uint256 amount, uint256 loss) {
        // defining total amount we want to burn in base asset value
        uint256 totalBurnAmount = Math.mulDiv(debt, pctNumerator, pctDenominator, Math.Rounding.Down);
        // defining total amount we want to burn in terms of LP quantity
        uint256 totalLpBurnAmount = Math.mulDiv(totalLpAmount(), pctNumerator, pctDenominator, Math.Rounding.Down);

        // 1) unstake from Maverick Rewarder if we cannot cover all (we prefer not to unstake as long as we can)
        uint256 unstakeLpAmount = 0;
        uint256 stakedLpBalance = stakedAmount();
        if (totalLpBurnAmount > stakedLpBalance) {
            unstakeLpAmount = totalLpBurnAmount - stakedLpBalance;
            MaverickStakingAdapter.unstakeLPs(maverickRewarder, unstakeLpAmount);
        }

        // 2) withdraw from Maverick Boosted Position

        //slither-disable-next-line similar-names
        (uint256 sellAmountA, uint256 sellAmountB) =
            boostedPosition.burnFromToAddressAsReserves(address(this), address(positionNft), totalLpBurnAmount);

        // 3) swap what we receive
        amount += _sellToken(address(pool.tokenA()), sellAmountA);
        amount += _sellToken(address(pool.tokenB()), sellAmountB);

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
