// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/access/AccessControl.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

import "../../interfaces/destinations/IDestinationAdapter.sol";
import "../..//libs/LibAdapter.sol";
import { IPool } from "../../interfaces/external/maverick/IPool.sol";
import { IRouter } from "../../interfaces/external/maverick/IRouter.sol";

import { console2 } from "forge-std/console2.sol";

contract MaverickAdapter is IDestinationAdapter, AccessControl, ReentrancyGuard {
    // event DeployLiquidity(
    //     uint256[] amountsDeposited,
    //     address[] tokens,
    //     // 0 - lpMintAmount
    //     // 1 - lpShare
    //     // 2 - lpTotalSupply
    //     uint256[3] lpAmounts,
    //     address poolAddress
    // );

    // event WithdrawLiquidity(
    //     uint256[] amountsWithdrawn,
    //     address[] tokens,
    //     // 0 - lpBurnAmount
    //     // 1 - lpShare
    //     // 2 - lpTotalSupply
    //     uint256[3] lpAmounts,
    //     address poolAddress
    // );

    struct AddLiquidityCallbackData {
        IERC20 tokenA;
        IERC20 tokenB;
        IPool pool;
        address payer;
    }

    error MustBeMoreThanZero();
    error MinLpAmountNotReached();
    error MinAmountNotReached();
    error LpTokenAmountMismatch();
    error MustNotBeZero();
    error TooManyAmountsProvided();
    error NoNonZeroAmountProvided();
    error InvalidBalanceChange();
    error InvalidAddress(address);

    receive() external payable { }

    struct MaverickExtraParams {
        address poolAddress;
        uint256 tokenId;
        uint256 deadline;
        IPool.AddLiquidityParams[] maverickParams;
        uint256 minAmountA;
        uint256 minAmountB;
    }

    IRouter public immutable router;

    constructor(IRouter _router) {
        if (address(_router) == address(0)) revert InvalidAddress(address(_router));

        router = _router;
    }

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minLpMintAmount,
        bytes calldata extraParams
    ) external nonReentrant {
        if (minLpMintAmount == 0) revert MustBeMoreThanZero();

        (MaverickExtraParams memory maverickExtraParams) = abi.decode(extraParams, (MaverickExtraParams));
        IPool.AddLiquidityParams[] memory maverickParams = maverickExtraParams.maverickParams;

        IPool pool = IPool(maverickExtraParams.poolAddress);

        LibAdapter._approve(pool.tokenA(), address(router), amounts[0]);
        LibAdapter._approve(pool.tokenB(), address(router), amounts[1]);

        // AddLiquidityCallbackData memory data =
        //     AddLiquidityCallbackData({tokenA: pool.tokenA(), tokenB: pool.tokenB(), pool: pool, payer:
        // address(this)});

        // bytes memory dataRes = abi.encode(data);

        // (uint256 tokenAAmount, uint256 tokenBAmount, IPool.BinDelta[] memory binDeltas) =
        //     pool.addLiquidity(maverickExtraParams.tokenId, maverickParams, abi.encode(data));

        /// @notice add liquidity to a pool
        /// @param pool pool to add liquidity to
        /// @param tokenId nft id of token that will hold lp balance, use 0 to mint a new token
        /// @param params paramters of liquidity addition
        /// @param minTokenAAmount minimum amount of token A to add, revert if not met
        /// @param minTokenBAmount minimum amount of token B to add, revert if not met
        /// @param deadline epoch timestamp in seconds
        // function addLiquidityToPool(
        //     IPool pool,
        //     uint256 tokenId,
        //     IPool.AddLiquidityParams[] calldata params,
        //     uint256 minTokenAAmount,
        //     uint256 minTokenBAmount,
        //     uint256 deadline

        (uint256 receivingTokenId, uint256 tokenAAmount, uint256 tokenBAmount, IPool.BinDelta[] memory binDeltas) =
        router.addLiquidityToPool(
            pool,
            maverickExtraParams.tokenId,
            maverickParams,
            maverickExtraParams.minAmountA,
            maverickExtraParams.minAmountB,
            maverickExtraParams.deadline
        );

        /// @notice return parameters for Add/Remove liquidity
        /// @param binId of the bin that changed
        /// @param kind one of the 4 Kinds (0=static, 1=right, 2=left, 3=both)
        /// @param isActive bool to indicate whether the bin is still active
        /// @param lowerTick is the lower price tick of the bin in its current state
        /// @param deltaA amount of A token that has been added or removed
        /// @param deltaB amount of B token that has been added or removed
        /// @param deltaLpToken amount of LP balance that has increase (add) or decreased (remove)
        // struct BinDelta {
        //     uint128 deltaA;
        //     uint128 deltaB;
        //     uint256 deltaLpBalance;
        //     uint128 binId;
        //     uint8 kind;
        //     int32 lowerTick;
        //     bool isActive;
        // }
        console2.log("result:");
        console2.log(binDeltas[0].deltaLpBalance);
        console2.log(binDeltas[0].binId);
    }

    function removeLiquidity(
        uint256[] calldata amounts,
        uint256 maxLpBurnAmount,
        bytes calldata extraParams
    ) external nonReentrant { }
}
