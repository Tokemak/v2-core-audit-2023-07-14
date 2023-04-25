// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IBaseRewardPool } from "../../../interfaces/external/convex/IBaseRewardPool.sol";
import { IConvexBooster } from "../../../interfaces/external/convex/IConvexBooster.sol";
import { IStakingAdapter } from "../../../interfaces/destinations/IStakingAdapter.sol";
import { LibAdapter } from "../../../libs/LibAdapter.sol";

contract ConvexAdapter is IStakingAdapter, ReentrancyGuard {
    event DeployLiquidity(address lpToken, address staking, uint256 poolId, uint256 amount);
    event WithdrawLiquidity(address lpToken, address staking, uint256 amount);

    error InvalidAddress();
    error MustBeGreaterThanZero();
    error BalanceMustIncrease();
    error withdrawStakeFailed();
    error DepositAndStakeFailed();
    error PoolIdLpTokenMismatch();
    error PoolIdStakingMismatch();

    /**
     * @notice Deposits and stakes Curve LP tokens to Convex
     * @dev Calls to external contract
     * @param booster Convex Booster address
     * @param lpToken Curve LP token to deposit
     * @param staking Convex reward contract associated with the Curve LP token
     * @param poolId Convex poolId for the associated Curve LP token
     * @param amount Quantity of Curve LP token to deposit and stake
     */
    function depositAndStake(
        IConvexBooster booster,
        address lpToken,
        address staking,
        uint256 poolId,
        uint256 amount
    ) external nonReentrant {
        // _validateToken(lpToken);  TODO: Call to Token Registry

        if (address(booster) == address(0)) revert InvalidAddress();
        if (staking == address(0)) revert InvalidAddress();
        if (amount == 0) revert MustBeGreaterThanZero();

        _validatePoolInfo(booster, poolId, lpToken, staking);

        IERC20 lpTokenErc = IERC20(lpToken);
        // _validateToken(lpTokenErc); TODO: Call to Token Registry
        LibAdapter._approve(lpTokenErc, address(booster), amount);

        IBaseRewardPool rewards = IBaseRewardPool(staking);
        uint256 rewardsBeforeBalance = rewards.balanceOf(address(this));

        _runDeposit(booster, poolId, amount);

        if (rewards.balanceOf(address(this)) - rewardsBeforeBalance != amount) {
            revert BalanceMustIncrease();
        }

        emit DeployLiquidity(lpToken, staking, poolId, amount);
    }

    /**
     * @notice Withdraws a Curve LP token from Convex
     * @dev Does not claim available rewards
     * @dev Calls to external contract
     * @param lpToken Curve LP token to withdraw
     * @param staking Convex reward contract associated with the Curve LP token
     * @param amount Quantity of Curve LP token to withdraw
     */
    function withdrawStake(address lpToken, address staking, uint256 amount) external nonReentrant {
        // _validateToken(lpToken); TODO: Call to Token Registry
        if (staking == address(0)) revert InvalidAddress();
        if (amount == 0) revert MustBeGreaterThanZero();

        IERC20 lpTokenErc = IERC20(lpToken);
        uint256 beforeLpBalance = lpTokenErc.balanceOf(address(this));

        IBaseRewardPool rewards = IBaseRewardPool(staking);

        bool success = rewards.withdrawAndUnwrap(amount, false);
        if (!success) revert withdrawStakeFailed();

        uint256 updatedLpBalance = lpTokenErc.balanceOf(address(this));
        if (updatedLpBalance - beforeLpBalance != amount) {
            revert BalanceMustIncrease();
        }

        emit WithdrawLiquidity(lpToken, staking, amount);
    }

    /// @dev Separate function to avoid stack-too-deep errors
    function _runDeposit(IConvexBooster booster, uint256 poolId, uint256 amount) private {
        bool success = booster.deposit(poolId, amount, true);
        if (!success) revert DepositAndStakeFailed();
    }

    /// @dev Separate function to avoid stack-too-deep errors
    function _validatePoolInfo(IConvexBooster booster, uint256 poolId, address lpToken, address staking) private {
        (address poolLpToken,,, address crvRewards,,) = booster.poolInfo(poolId);
        if (lpToken != poolLpToken) revert PoolIdLpTokenMismatch();
        if (staking != crvRewards) revert PoolIdStakingMismatch();
    }
}
