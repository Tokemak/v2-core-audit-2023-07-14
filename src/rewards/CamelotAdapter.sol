// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { INFTPool } from "../interfaces/external/camelot/INFTPool.sol";
import { INFTHandler } from "../interfaces/external/camelot/INFTHandler.sol";
import { IClaimableRewards } from "./IClaimableRewards.sol";

contract CamelotAdapter is IClaimableRewards, INFTHandler, ReentrancyGuard {
    error WrongOperator(address expected, address actual);
    error WrongTo(address expected, address actual);

    event OnNFTHarvest(address operator, address to, uint256 tokenId, uint256 grailAmount, uint256 xGrailAmount);

    // slither-disable-start similar-names
    IERC20 public immutable grailToken;
    IERC20 public immutable xGrailToken;
    // slither-disable-end similar-names

    constructor(IERC20 _grailToken, IERC20 _xGrailToken) {
        if (address(_grailToken) == address(0)) revert TokenAddressZero();
        if (address(_xGrailToken) == address(0)) revert TokenAddressZero();

        grailToken = _grailToken;
        xGrailToken = _xGrailToken;
    }

    // slither-disable-start calls-loop
    /**
     * @param nftPoolAddress The NFT pool to claim rewards from
     */
    function claimRewards(address nftPoolAddress) public nonReentrant returns (uint256[] memory, IERC20[] memory) {
        if (nftPoolAddress == address(0)) revert TokenAddressZero();

        address account = address(this);

        INFTPool nftPool = INFTPool(nftPoolAddress);

        uint256 grailTokenBalanceBefore = grailToken.balanceOf(account);
        uint256 xGrailTokenBalanceBefore = xGrailToken.balanceOf(account);

        // get the length of positions NFTs
        uint256 length = nftPool.balanceOf(account);

        // harvest all positions
        for (uint256 i = 0; i < length; ++i) {
            uint256 tokenId = nftPool.tokenOfOwnerByIndex(account, i);
            nftPool.harvestPosition(tokenId);
        }

        uint256 grailTokenBalanceAfter = grailToken.balanceOf(account);
        uint256 xGrailTokenBalanceAfter = xGrailToken.balanceOf(account);

        IERC20[] memory rewardTokens = new IERC20[](2);
        uint256[] memory amountsClaimed = new uint256[](2);

        rewardTokens[0] = grailToken;
        amountsClaimed[0] = grailTokenBalanceAfter - grailTokenBalanceBefore;
        rewardTokens[1] = xGrailToken;
        amountsClaimed[1] = xGrailTokenBalanceAfter - xGrailTokenBalanceBefore;

        emit RewardsClaimed(rewardTokens, amountsClaimed);

        return (amountsClaimed, rewardTokens);
    }
    // slither-disable-end calls-loop

    /**
     * @notice This function is required by Camelot NFTPool if the msg.sender is a contract, to confirm whether it is
     * able to handle reward harvesting.
     */
    function onNFTHarvest(
        address operator,
        address to,
        uint256 tokenId,
        uint256 grailAmount,
        uint256 xGrailAmount
    ) external returns (bool) {
        if (operator != address(this)) revert WrongOperator(address(this), operator);

        // prevent for harvesting to other address
        if (to != address(this)) revert WrongTo(address(this), to);

        emit OnNFTHarvest(operator, to, tokenId, grailAmount, xGrailAmount);
        return true;
    }
}
