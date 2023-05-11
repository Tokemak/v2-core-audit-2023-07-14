// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC721Receiver } from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IPoolAdapter } from "../../interfaces/destinations/IPoolAdapter.sol";
import { IPool } from "../../interfaces/external/maverick/IPool.sol";
import { IPosition } from "../../interfaces/external/maverick/IPosition.sol";
import { IRouter } from "../../interfaces/external/maverick/IRouter.sol";
import { LibAdapter } from "../../libs/LibAdapter.sol";

//slither-disable-start similar-names
contract MaverickAdapter is IPoolAdapter, ReentrancyGuard {
    event DeployLiquidity(
        uint256[2] amountsDeposited,
        address[2] tokens,
        // 0 - lpMintAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address poolAddress,
        uint256 receivingTokenId,
        uint256[] deployedBinIds
    );

    event WithdrawLiquidity(
        uint256[2] amountsWithdrawn,
        address[2] tokens,
        // 0 - lpBurnAmount
        // 1 - lpShare
        // 2 - lpTotalSupply
        uint256[3] lpAmounts,
        address poolAddress,
        uint256 receivingTokenId,
        uint256[] deployedBinIds
    );

    struct MaverickDeploymentExtraParams {
        address poolAddress;
        uint256 tokenId;
        uint256 deadline;
        IPool.AddLiquidityParams[] maverickParams;
    }

    struct MaverickWithdrawalExtraParams {
        address poolAddress;
        uint256 tokenId;
        uint256 deadline;
        IPool.RemoveLiquidityParams[] maverickParams;
    }

    IRouter public immutable router;

    constructor(IRouter _router) {
        if (address(_router) == address(0)) revert InvalidAddress(address(_router));
        router = _router;
    }

    receive() external payable { }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minLpMintAmount,
        bytes calldata extraParams
    ) external nonReentrant {
        if (minLpMintAmount == 0) revert MustBeMoreThanZero();
        if (amounts.length != 2) revert ArraysLengthMismatch();
        if (amounts[0] == 0 && amounts[1] == 0) revert NoNonZeroAmountProvided();

        (MaverickDeploymentExtraParams memory maverickExtraParams) =
            abi.decode(extraParams, (MaverickDeploymentExtraParams));

        _approveTokens(maverickExtraParams);

        (uint256 receivingTokenId, uint256 tokenAAmount, uint256 tokenBAmount, IPool.BinDelta[] memory binDeltas) =
        router.addLiquidityToPool(
            IPool(maverickExtraParams.poolAddress),
            maverickExtraParams.tokenId,
            maverickExtraParams.maverickParams,
            amounts[0],
            amounts[1],
            maverickExtraParams.deadline
        );

        // Collect deployed bins data
        (
            uint256 binslpAmountSummary,
            uint256 binslpBalanceSummary,
            uint256 binsLpTotalSupplySummary,
            uint256[] memory deployedBinIds
        ) = _collectBinSummary(binDeltas, IPool(maverickExtraParams.poolAddress), maverickExtraParams.tokenId);

        if (binslpAmountSummary < minLpMintAmount) revert MinLpAmountNotReached();
        if (tokenAAmount < amounts[0]) revert InvalidBalanceChange();
        if (tokenBAmount < amounts[1]) revert InvalidBalanceChange();

        emit DeployLiquidity(
            [tokenAAmount, tokenBAmount],
            [
                address(IPool(maverickExtraParams.poolAddress).tokenA()),
                address(IPool(maverickExtraParams.poolAddress).tokenB())
            ],
            [binslpAmountSummary, binslpBalanceSummary, binsLpTotalSupplySummary],
            maverickExtraParams.poolAddress,
            receivingTokenId,
            deployedBinIds
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

        (MaverickWithdrawalExtraParams memory maverickExtraParams) =
            abi.decode(extraParams, (MaverickWithdrawalExtraParams));

        router.position().approve(address(router), maverickExtraParams.tokenId);

        (uint256 tokenAAmount, uint256 tokenBAmount, IPool.BinDelta[] memory binDeltas) =
            _runWithdrawal(amounts, maverickExtraParams);

        // Collect deployed bins data
        (
            uint256 binslpAmountSummary,
            uint256 binslpBalanceSummary,
            uint256 binsLpTotalSupplySummary,
            uint256[] memory deployedBinIds
        ) = _collectBinSummary(binDeltas, IPool(maverickExtraParams.poolAddress), maverickExtraParams.tokenId);

        if (binslpAmountSummary > maxLpBurnAmount) revert LpTokenAmountMismatch();
        if (tokenAAmount < amounts[0]) revert InvalidBalanceChange();
        if (tokenBAmount < amounts[1]) revert InvalidBalanceChange();

        actualAmounts = new uint256[](2);
        actualAmounts[0] = tokenAAmount;
        actualAmounts[1] = tokenBAmount;

        emit WithdrawLiquidity(
            [tokenAAmount, tokenBAmount],
            [
                address(IPool(maverickExtraParams.poolAddress).tokenA()),
                address(IPool(maverickExtraParams.poolAddress).tokenB())
            ],
            [binslpAmountSummary, binslpBalanceSummary, binsLpTotalSupplySummary],
            maverickExtraParams.poolAddress,
            maverickExtraParams.tokenId,
            deployedBinIds
        );
    }

    ///@dev Adoiding stack-too-deep-errors
    function _runWithdrawal(
        uint256[] calldata amounts,
        MaverickWithdrawalExtraParams memory maverickExtraParams
    ) private returns (uint256 tokenAAmount, uint256 tokenBAmount, IPool.BinDelta[] memory binDeltas) {
        (tokenAAmount, tokenBAmount, binDeltas) = router.removeLiquidity(
            IPool(maverickExtraParams.poolAddress),
            address(this),
            maverickExtraParams.tokenId,
            maverickExtraParams.maverickParams,
            amounts[0],
            amounts[1],
            maverickExtraParams.deadline
        );
    }

    function _approveTokens(MaverickDeploymentExtraParams memory maverickExtraParams) private {
        IPool.AddLiquidityParams[] memory maverickParams = maverickExtraParams.maverickParams;

        uint256[] memory approvalSummary = new uint256[](2);
        for (uint256 i = 0; i < maverickParams.length; ++i) {
            approvalSummary[0] += maverickParams[i].deltaA;
            approvalSummary[1] += maverickParams[i].deltaB;
        }
        LibAdapter._approve(IPool(maverickExtraParams.poolAddress).tokenA(), address(router), approvalSummary[0]);
        LibAdapter._approve(IPool(maverickExtraParams.poolAddress).tokenB(), address(router), approvalSummary[1]);
    }

    function _collectBinSummary(
        IPool.BinDelta[] memory binDeltas,
        IPool pool,
        uint256 tokenId
    )
        private
        view
        returns (
            uint256 binslpAmountSummary,
            uint256 binslpBalanceSummary,
            uint256 binsLpTotalSupplySummary,
            uint256[] memory affectedBinIds
        )
    {
        affectedBinIds = new uint256[](binDeltas.length);
        for (uint256 i = 0; i < binDeltas.length; ++i) {
            IPool.BinDelta memory bin = binDeltas[i];
            affectedBinIds[i] = bin.binId;
            binslpAmountSummary += bin.deltaLpBalance;
            binslpBalanceSummary += pool.balanceOf(tokenId, bin.binId);
            binsLpTotalSupplySummary += pool.getBin(bin.binId).totalSupply;
        }
    }
}
//slither-disable-end similar-names
