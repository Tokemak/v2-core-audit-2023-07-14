// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IStakingAdapter } from "../../../interfaces/destinations/IStakingAdapter.sol";
import { IVoter } from "../../../interfaces/external/velodrome/IVoter.sol";
import { IVotingEscrow } from "../../../interfaces/external/velodrome/IVotingEscrow.sol";
import { IGauge } from "../../../interfaces/external/velodrome/IGauge.sol";
import { IBaseBribe } from "../../../interfaces/external/velodrome/IBaseBribe.sol";
import { IWrappedExternalBribeFactory } from "../../../interfaces/external/velodrome/IWrappedExternalBribeFactory.sol";
import { IRewardsDistributor } from "../../../interfaces/external/velodrome/IRewardsDistributor.sol";
import { IPair } from "../../../interfaces/external/velodrome/IPair.sol";
import { LibAdapter } from "../../../libs/LibAdapter.sol";

contract VelodromeStakingAdapter is IStakingAdapter, ReentrancyGuard {
    event DeployLiquidity(
        uint256[] amountsDeposited,
        uint256[] tokensIds,
        // 0 - lpMintAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address pool,
        address guageAddress,
        address staking
    );

    event WithdrawLiquidity(
        uint256[] amountsWithdrawn,
        uint256[] tokensIds,
        // 0 - lpMintAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address pool,
        address guageAddress,
        address staking
    );

    IVoter public immutable voter;

    constructor(address _voter) {
        if (_voter == address(0)) revert InvalidAddress(_voter);
        voter = IVoter(_voter);
    }

    /**
     * @notice Stakes tokens to Velodrome
     * @dev Calls to external contract
     * @param amounts amounts of corresponding tokenIds to add
     * @param tokenIds ids for the associated LP tokens
     * @param minLpMintAmount min amount to reach in result of staking (for all tokens in summary)
     * @param pool corresponding pool of the deposited tokens
     */
    function stakeLPs(
        uint256[] calldata amounts,
        uint256[] calldata tokenIds,
        uint256 minLpMintAmount,
        address pool
    ) public nonReentrant {
        if (minLpMintAmount == 0) revert MustBeMoreThanZero();
        if (amounts.length == 0 || amounts.length != tokenIds.length) revert ArraysLengthMismatch();
        if (pool == address(0)) revert InvalidAddress(pool);

        address gaugeAddress = voter.gauges(pool);
        IGauge gauge = IGauge(gaugeAddress);

        uint256 lpTokensBefore = gauge.balanceOf(address(this));
        //slither-disable-start calls-loop
        for (uint256 i = 0; i < amounts.length; ++i) {
            LibAdapter._approve(IERC20(gauge.stake()), address(gauge), amounts[i]);
            gauge.deposit(amounts[i], tokenIds[i]);
        }
        //slither-disable-end calls-loop
        uint256 lpTokensAfter = gauge.balanceOf(address(this));
        uint256 lpTokenAmount = lpTokensAfter - lpTokensBefore;
        if (lpTokenAmount < minLpMintAmount) revert MinLpAmountNotReached();

        emit DeployLiquidity(
            amounts,
            tokenIds,
            [lpTokenAmount, lpTokensAfter, gauge.totalSupply()],
            pool,
            address(gauge),
            address(gauge.stake())
            );
    }

    /**
     * @notice Unstakes tokens from Velodrome
     * @dev Calls to external contract
     * @param amounts amounts of corresponding tokenIds to add
     * @param tokenIds ids for the associated LP tokens
     * @param maxLpBurnAmount max amount to burn in result of unstaking (for all tokens in summary)
     * @param pool corresponding pool of the deposited tokens
     */
    function unstakeLPs(
        uint256[] calldata amounts,
        uint256[] calldata tokenIds,
        uint256 maxLpBurnAmount,
        address pool
    ) public nonReentrant {
        if (maxLpBurnAmount == 0) revert MustBeMoreThanZero();
        if (amounts.length == 0 || amounts.length != tokenIds.length) revert ArraysLengthMismatch();
        if (pool == address(0)) revert InvalidAddress(pool);

        address gaugeAddress = voter.gauges(pool);
        IGauge gauge = IGauge(gaugeAddress);

        uint256 lpTokensBefore = gauge.balanceOf(address(this));

        //slither-disable-start calls-loop
        for (uint256 i = 0; i < amounts.length; ++i) {
            gauge.withdrawToken(amounts[i], tokenIds[i]);
        }
        //slither-disable-end calls-loop

        uint256 lpTokensAfter = gauge.balanceOf(address(this));

        uint256 lpTokenAmount = lpTokensBefore - lpTokensAfter;
        if (lpTokenAmount > maxLpBurnAmount) revert LpTokenAmountMismatch();

        emit WithdrawLiquidity(
            amounts,
            tokenIds,
            [lpTokenAmount, lpTokensAfter, gauge.totalSupply()],
            pool,
            address(gauge),
            address(gauge.stake())
            );
    }
}
