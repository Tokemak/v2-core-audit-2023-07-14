// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IBaseRewardPool } from "../interfaces/external/convex/IBaseRewardPool.sol";
import { IConvexBooster } from "../interfaces/external/convex/IConvexBooster.sol";
import { IClaimableRewards } from "./IClaimableRewards.sol";
import "../libs/LibAdapter.sol";

contract ConvexAdapter is IClaimableRewards, ReentrancyGuard {
    error InvalidAddress();
    error MustBeGreaterThanZero();
    error BalanceMustIncrease();
    error WithdrawStakeFailed();
    error DepositAndStakeFailed();
    error PoolIdLpTokenMismatch();
    error PoolIdStakingMismatch();

    /// @notice Deposits and stakes Curve LP tokens to Convex
    /// @dev Calls to external contract
    /// @param lpToken Curve LP token to deposit
    /// @param staking Convex reward contract associated with the Curve LP token
    /// @param poolId Convex poolId for the associated Curve LP token
    /// @param amount Quantity of Curve LP token to deposit and stake
    function depositAndStakeConvex(
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
    function withdrawStakeConvex(address lpToken, address staking, uint256 amount) external nonReentrant {
        // _validateToken(lpToken); TODO: Call to Token Registry
        if (staking == address(0)) revert InvalidAddress();
        if (amount == 0) revert MustBeGreaterThanZero();

        IERC20 lpTokenErc = IERC20(lpToken);
        uint256 beforeLpBalance = lpTokenErc.balanceOf(address(this));

        IBaseRewardPool rewards = IBaseRewardPool(staking);
        uint256 rewardsBeforeBalance = rewards.balanceOf(address(this));

        bool success = rewards.withdrawAndUnwrap(amount, false);
        if (!success) revert WithdrawStakeFailed();

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

    // slither-disable-start calls-loop
    /**
     * @param gauge The gauge to claim rewards from
     */
    function claimRewards(address gauge) public nonReentrant returns (uint256[] memory, IERC20[] memory) {
        if (gauge == address(0)) revert TokenAddressZero();

        address account = address(this);

        IBaseRewardPool rewardPool = IBaseRewardPool(gauge);
        uint256 extraRewardsLength = rewardPool.extraRewardsLength();

        uint256[] memory balancesBefore = new uint256[](extraRewardsLength + 1);
        uint256[] memory amountsClaimed = new uint256[](extraRewardsLength + 1);
        IERC20[] memory rewardTokens = new IERC20[](extraRewardsLength + 1);

        // add pool rewards tokens and extra rewards tokens to rewardTokens array
        IERC20 rewardToken = rewardPool.rewardToken();
        rewardTokens[extraRewardsLength] = rewardToken;
        if (extraRewardsLength > 0) {
            for (uint256 i = 0; i < extraRewardsLength; ++i) {
                address extraReward = rewardPool.extraRewards(i);
                rewardTokens[i] = IBaseRewardPool(extraReward).rewardToken();
            }
        }

        // get balances before
        uint256 tokensLength = rewardTokens.length;
        for (uint256 i = 0; i < tokensLength; ++i) {
            balancesBefore[i] = rewardTokens[i].balanceOf(account);
        }

        // claim rewards
        bool result = rewardPool.getReward(account, true);
        if (!result) {
            revert ClaimRewardsFailed();
        }

        // get balances after and calculate amounts claimed
        for (uint256 i = 0; i < tokensLength; ++i) {
            uint256 balance = rewardTokens[i].balanceOf(account);

            amountsClaimed[i] = balance - balancesBefore[i];
        }

        emit RewardsClaimed(rewardTokens, amountsClaimed);

        return (amountsClaimed, rewardTokens);
    }
    // slither-disable-end calls-loop

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
