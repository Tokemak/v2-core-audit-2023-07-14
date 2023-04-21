// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

import "../../../interfaces/external/convex/IBaseRewardPool.sol";
import "../../../interfaces/external/convex/IConvexBooster.sol";
import "../../../interfaces/destinations/IStakingAdapter.sol";
import "../../../libs/LibAdapter.sol";

// TODO: clenup
contract ConvexAdapter is IStakingAdapter, ReentrancyGuard {
    error InvalidAddress();
    error MustBeGreaterThanZero();
    error BalanceMustIncrease();
    error withdrawStakeFailed();
    error DepositAndStakeFailed();
    error PoolIdLpTokenMismatch();
    error PoolIdStakingMismatch();

    /// @notice Deposits and stakes Curve LP tokens to Convex
    /// @dev Calls to external contract
    /// @param lpToken Curve LP token to deposit
    /// @param staking Convex reward contract associated with the Curve LP token
    /// @param poolId Convex poolId for the associated Curve LP token
    /// @param amount Quantity of Curve LP token to deposit and stake
    function depositAndStake(
        IConvexBooster booster,
        address lpToken,
        address staking,
        uint256 poolId,
        uint256 amount
    ) external nonReentrant {
        // _validateToken(lpToken);  TODO: Call to Token Registry

        if (staking == address(0)) revert InvalidAddress();
        if (amount == 0) revert MustBeGreaterThanZero();

        _validatePoolInfo(booster, poolId, lpToken, staking);

        IERC20 lpTokenErc = IERC20(lpToken);
        // _validateToken(lpTokenErc); TODO: Call to Token Registry
        LibAdapter._approve(lpTokenErc, address(booster), amount);
        uint256 lpBalanceBefore = lpTokenErc.balanceOf(address(this));

        IBaseRewardPool rewards = IBaseRewardPool(staking);
        uint256 rewardsBeforeBalance = rewards.balanceOf(address(this));

        _runDeposit(booster, poolId, amount);

        if (rewards.balanceOf(address(this)) - rewardsBeforeBalance != amount) {
            revert BalanceMustIncrease();
        }

        // emit DeployLiquidity(
        //     LibController._toDynamicArray(lpBalanceBefore - lpTokenErc.balanceOf(address(this))),
        //     LibController._toDynamicArray(lpToken),
        //     amount,
        //     rewards.balanceOf(address(this)),
        //     rewards.totalSupply(),
        //     abi.encode(poolId, staking)
        //     );
    }

    /// @notice Withdraws a Curve LP token from Convex
    /// @dev Does not claim available rewards
    /// @dev Calls to external contract
    /// @param lpToken Curve LP token to withdraw
    /// @param staking Convex reward contract associated with the Curve LP token
    /// @param amount Quantity of Curve LP token to withdraw
    function withdrawStake(address lpToken, address staking, uint256 amount) external nonReentrant {
        // _validateToken(lpToken); TODO: Call to Token Registry
        if (staking == address(0)) revert InvalidAddress();
        if (amount == 0) revert MustBeGreaterThanZero();

        IERC20 lpTokenErc = IERC20(lpToken);
        uint256 beforeLpBalance = lpTokenErc.balanceOf(address(this));

        IBaseRewardPool rewards = IBaseRewardPool(staking);
        uint256 rewardsBeforeBalance = rewards.balanceOf(address(this));

        bool success = rewards.withdrawAndUnwrap(amount, false);
        if (!success) revert withdrawStakeFailed();

        uint256 updatedLpBalance = lpTokenErc.balanceOf(address(this));
        if (updatedLpBalance - beforeLpBalance != amount) {
            revert BalanceMustIncrease();
        }

        uint256 rewardsAfterBalance = rewards.balanceOf(address(this));

        // emit WithdrawLiquidity(
        //     LibController._toDynamicArray(updatedLpBalance - beforeLpBalance),
        //     LibController._toDynamicArray(lpToken),
        //     rewardsBeforeBalance - rewardsAfterBalance,
        //     rewardsAfterBalance,
        //     rewards.totalSupply(),
        //     abi.encode(staking)
        //     );
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
