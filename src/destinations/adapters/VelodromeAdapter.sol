// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IPoolAdapter } from "../../interfaces/destinations/IPoolAdapter.sol";
import { IRouter } from "../../interfaces/external/velodrome/IRouter.sol";
import { IVotingEscrow } from "../../interfaces/external/velodrome/IVotingEscrow.sol";
import { IGauge } from "../../interfaces/external/velodrome/IGauge.sol";
import { IBaseBribe } from "../../interfaces/external/velodrome/IBaseBribe.sol";
import { IWrappedExternalBribeFactory } from "../../interfaces/external/velodrome/IWrappedExternalBribeFactory.sol";
import { IRewardsDistributor } from "../../interfaces/external/velodrome/IRewardsDistributor.sol";
import { IPair } from "../../interfaces/external/velodrome/IPair.sol";
import { LibAdapter } from "../../libs/LibAdapter.sol";

contract VelodromeAdapter is IPoolAdapter, ReentrancyGuard {
    event DeployLiquidity(
        uint256[2] amountsDeposited,
        address[2] tokens,
        // 0 - lpMintAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address pairAddress
    );

    event WithdrawLiquidity(
        uint256[2] amountsWithdrawn,
        address[2] tokens,
        // 0 - lpBurnAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address pairAddress
    );

    struct VelodromeExtraParams {
        address tokenA;
        address tokenB;
        bool stable;
        uint256 amountAMin;
        uint256 amountBMin;
        uint256 deadline;
    }

    IRouter public immutable router;

    constructor(address _router) {
        if (_router == address(0)) revert InvalidAddress(_router);
        router = IRouter(_router);
    }

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minLpMintAmount,
        bytes calldata extraParams
    ) public nonReentrant {
        if (minLpMintAmount == 0) revert MustBeMoreThanZero();
        if (amounts.length != 2) revert ArraysLengthMismatch();
        if (amounts[0] == 0 && amounts[1] == 0) revert NoNonZeroAmountProvided();

        (VelodromeExtraParams memory velodromeExtraParams) = abi.decode(extraParams, (VelodromeExtraParams));

        LibAdapter._approve(IERC20(velodromeExtraParams.tokenA), address(router), amounts[0]);
        LibAdapter._approve(IERC20(velodromeExtraParams.tokenB), address(router), amounts[1]);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            velodromeExtraParams.tokenA,
            velodromeExtraParams.tokenB,
            velodromeExtraParams.stable,
            amounts[0],
            amounts[1],
            velodromeExtraParams.amountAMin,
            velodromeExtraParams.amountBMin,
            address(this),
            velodromeExtraParams.deadline
        );

        if (liquidity < minLpMintAmount) revert MinLpAmountNotReached();
        if (amountA > amounts[0]) revert InvalidBalanceChange();
        if (amountB > amounts[1]) revert InvalidBalanceChange();

        IPair pair = _getPair(velodromeExtraParams);

        emit DeployLiquidity(
            [amountA, amountB],
            [velodromeExtraParams.tokenA, velodromeExtraParams.tokenB],
            [liquidity, pair.balanceOf(address(this)), pair.totalSupply()],
            address(pair)
        );
    }

    function removeLiquidity(
        uint256[] calldata amounts,
        uint256 maxLpBurnAmount,
        bytes calldata extraParams
    ) external nonReentrant returns (uint256[] memory actualAmounts) {
        if (maxLpBurnAmount == 0) revert MustBeMoreThanZero();
        if (amounts.length != 2) revert ArraysLengthMismatch();
        if (amounts[0] == 0 && amounts[1] == 0) revert NoNonZeroAmountProvided();

        (VelodromeExtraParams memory velodromeExtraParams) = abi.decode(extraParams, (VelodromeExtraParams));

        IPair pair = _getPair(velodromeExtraParams);

        LibAdapter._approve(pair, address(router), maxLpBurnAmount);

        uint256 lpTokensBefore = pair.balanceOf(address(this));

        (uint256 amountA, uint256 amountB) = _runWithdrawal(amounts, maxLpBurnAmount, velodromeExtraParams);
        uint256 lpTokensAfter = pair.balanceOf(address(this));

        uint256 lpTokenAmount = lpTokensBefore - lpTokensAfter;
        if (lpTokenAmount > maxLpBurnAmount) {
            revert LpTokenAmountMismatch();
        }
        if (amountA < amounts[0]) revert InvalidBalanceChange();
        if (amountB < amounts[1]) revert InvalidBalanceChange();

        actualAmounts = new uint256[](2);
        actualAmounts[0] = amountA;
        actualAmounts[1] = amountB;

        emit WithdrawLiquidity(
            [amountA, amountB],
            [velodromeExtraParams.tokenA, velodromeExtraParams.tokenB],
            [lpTokenAmount, lpTokensAfter, pair.totalSupply()],
            address(pair)
        );
    }

    function _runWithdrawal(
        uint256[] calldata amounts,
        uint256 maxLpBurnAmount,
        VelodromeExtraParams memory params
    ) private returns (uint256 amountA, uint256 amountB) {
        return router.removeLiquidity(
            params.tokenA,
            params.tokenB,
            params.stable,
            maxLpBurnAmount,
            amounts[0],
            amounts[1],
            address(this),
            params.deadline
        );
    }

    function _getPair(VelodromeExtraParams memory params) private view returns (IPair pair) {
        pair = IPair(router.pairFor(params.tokenA, params.tokenB, params.stable));
    }
}
