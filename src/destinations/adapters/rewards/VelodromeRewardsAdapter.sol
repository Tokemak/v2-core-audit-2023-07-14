// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IClaimableRewardsAdapter } from "../../../interfaces/destinations/IClaimableRewardsAdapter.sol";
import { IVoter } from "../../../interfaces/external/velodrome/IVoter.sol";
import { IVotingEscrow } from "../../../interfaces/external/velodrome/IVotingEscrow.sol";
import { IGauge } from "../../../interfaces/external/velodrome/IGauge.sol";
import { IBaseBribe } from "../../../interfaces/external/velodrome/IBaseBribe.sol";
import { IWrappedExternalBribeFactory } from "../../../interfaces/external/velodrome/IWrappedExternalBribeFactory.sol";
import { IRewardsDistributor } from "../../../interfaces/external/velodrome/IRewardsDistributor.sol";

/**
 * @title VelodromeRewardsAdapter
 * @dev This contract implements an adapter for interacting with Velodrome Finance's reward system.
 * The Velodrome Finance platform offers four types of rewards:
 *  - Emissions:  rewards distributed to liquidity providers based on their share of the liquidity pool.
 *      - _claimEmissions() is used to claim these rewards.
 *  - Fees: rewards distributed to users who interact with the platform through trades or other actions.
 *      - _claimFees() is used to claim these rewards.
 *  - Bribes: rewards distributed to users who vote in governance proposals.
 *      - _claimBribes() is used to claim these rewards.
 *  - Rebases: rewards distributed to users who hold a particular token during a rebase event.
 *      - _rebase() is used to claim these rewards.
 *      - 🚨This contract does not use rebases yet.🚨
 */
contract VelodromeRewardsAdapter is IClaimableRewardsAdapter, ReentrancyGuard {
    enum ClaimType {
        Bribes,
        Fees
    }

    error InvalidClaimType();

    // solhint-disable-next-line var-name-mixedcase
    IVoter public immutable VOTER;
    // solhint-disable-next-line var-name-mixedcase
    IWrappedExternalBribeFactory public immutable WRAPPED_BRIBE_FACTORY;
    // solhint-disable-next-line var-name-mixedcase
    IVotingEscrow public immutable VOTING_ESCROW;
    // solhint-disable-next-line var-name-mixedcase
    IRewardsDistributor public immutable REWARDS_DISTRIBUTOR;

    constructor(address voter, address wrappedBribeFactory, address votingEscrow, address rewardsDistributor) {
        if (voter == address(0)) revert TokenAddressZero();
        if (wrappedBribeFactory == address(0)) revert TokenAddressZero();
        if (votingEscrow == address(0)) revert TokenAddressZero();
        if (rewardsDistributor == address(0)) revert TokenAddressZero();

        VOTER = IVoter(voter);
        WRAPPED_BRIBE_FACTORY = IWrappedExternalBribeFactory(wrappedBribeFactory);
        VOTING_ESCROW = IVotingEscrow(votingEscrow);
        REWARDS_DISTRIBUTOR = IRewardsDistributor(rewardsDistributor);
    }

    /**
     * @param pool The pool to claim rewards from
     */
    function claimRewards(address pool) public nonReentrant returns (uint256[] memory, IERC20[] memory) {
        address gaugeAddress = VOTER.gauges(pool);

        uint256[] memory tokensIds = _getAccountTokenIds(_getContractAddress());

        (uint256[] memory amountsFees, IERC20[] memory feesTokens) = _claimFees(gaugeAddress, tokensIds);

        (uint256[] memory amountsBribes, IERC20[] memory bribesTokens) = _claimBribes(gaugeAddress, tokensIds);

        (uint256[] memory amountsEmissions, IERC20[] memory emissionsTokens) = _claimEmissions(gaugeAddress);

        (uint256[] memory amountsMerged, IERC20[] memory rewardTokensMerged) =
            _mergeArrays(feesTokens, amountsFees, bribesTokens, amountsBribes);

        (uint256[] memory amountsClaimed, IERC20[] memory rewardTokens) =
            _mergeArrays(rewardTokensMerged, amountsMerged, emissionsTokens, amountsEmissions);

        emit RewardsClaimed(rewardTokens, amountsClaimed);
        return (amountsClaimed, rewardTokens);
    }

    function _claimEmissions(address gaugeAddress)
        private
        returns (uint256[] memory amountsClaimed, IERC20[] memory rewards)
    {
        IGauge gauge = IGauge(gaugeAddress);
        address[] memory gaugeRewards = _getGaugeRewards(gauge);

        uint256 count = gaugeRewards.length;
        uint256[] memory balancesBefore = new uint256[](count);
        amountsClaimed = new uint256[](count);
        rewards = new IERC20[](count);

        for (uint256 i = 0; i < count; ++i) {
            IERC20 reward = IERC20(gaugeRewards[i]);
            rewards[i] = reward;
            balancesBefore[i] = reward.balanceOf(_getContractAddress());
        }

        gauge.getReward(_getContractAddress(), gaugeRewards);

        for (uint256 i = 0; i < count; ++i) {
            uint256 balanceAfter = rewards[i].balanceOf(_getContractAddress());
            amountsClaimed[i] = balanceAfter - balancesBefore[i];
        }

        return (amountsClaimed, rewards);
    }

    function _claimFees(
        address gaugeAddress,
        uint256[] memory tokensIds
    ) private returns (uint256[] memory amountsClaimed, IERC20[] memory rewards) {
        address internalBribes = VOTER.internal_bribes(gaugeAddress);
        return _claimBribesOrFees(internalBribes, tokensIds, ClaimType.Fees);
    }

    function _claimBribes(
        address gaugeAddress,
        uint256[] memory tokensIds
    ) private returns (uint256[] memory amountsClaimed, IERC20[] memory rewards) {
        address externalBribes = VOTER.external_bribes(gaugeAddress);

        address wrappedBribe = WRAPPED_BRIBE_FACTORY.oldBribeToNew(externalBribes);

        if (wrappedBribe != address(0)) {
            externalBribes = wrappedBribe;
        }
        return _claimBribesOrFees(externalBribes, tokensIds, ClaimType.Bribes);
    }

    function _claimBribesOrFees(
        address bribe,
        uint256[] memory tokensIds,
        ClaimType claimType
    ) private returns (uint256[] memory amountsClaimed, IERC20[] memory rewardTokens) {
        address[] memory rewards = _getBribeRewards(bribe);
        uint256 count = rewards.length;
        uint256[] memory balancesBefore = new uint256[](count);
        rewardTokens = new IERC20[](count);
        amountsClaimed = new uint256[](count);

        for (uint256 i = 0; i < count; ++i) {
            IERC20 reward = IERC20(rewards[i]);
            rewardTokens[i] = IERC20(reward);
            balancesBefore[i] = reward.balanceOf(_getContractAddress());
        }

        address[] memory fees = addressToArray(bribe);
        address[][] memory tokens = arrayToMatrix(rewards);

        uint256 tokensIdsLength = tokensIds.length;
        for (uint256 i = 0; i < tokensIdsLength; ++i) {
            uint256 tokenId = tokensIds[i];
            if (claimType == ClaimType.Bribes) {
                VOTER.claimBribes(fees, tokens, tokenId);
            } else if (claimType == ClaimType.Fees) {
                VOTER.claimFees(fees, tokens, tokenId);
            } else {
                revert InvalidClaimType();
            }
        }

        for (uint256 i = 0; i < count; ++i) {
            IERC20 reward = rewardTokens[i];
            uint256 balanceAfter = reward.balanceOf(_getContractAddress());
            amountsClaimed[i] = balanceAfter - balancesBefore[i];
        }
    }

    // @dev This function is used to claim rewards yet as it not only claims rewards but also stack the tokens
    // slither-disable-next-line dead-code
    function _rebase(uint256[] memory tokensIds) private {
        bool success = REWARDS_DISTRIBUTOR.claim_many(tokensIds);
        if (!success) {
            revert ClaimRewardsFailed();
        }
    }

    function _getGaugeRewards(IGauge gauge) private view returns (address[] memory rewards) {
        uint256 length = gauge.rewardsListLength();

        rewards = new address[](length);

        for (uint256 i = 0; i < length; ++i) {
            address reward = gauge.rewards(i);
            rewards[i] = reward;
        }

        return rewards;
    }

    function _getAccountTokenIds(address account) private view returns (uint256[] memory tokensIds) {
        uint256 balance = VOTING_ESCROW.balanceOf(_getContractAddress());
        tokensIds = new uint256[](balance);

        for (uint256 i = 0; i < balance; ++i) {
            uint256 tokenId = VOTING_ESCROW.tokenOfOwnerByIndex(account, i);
            tokensIds[i] = tokenId;
        }
    }

    function _getBribeRewards(address bribe) private view returns (address[] memory rewards) {
        IBaseBribe internalBribe = IBaseBribe(bribe);

        uint256 rewardsListLength = internalBribe.rewardsListLength();
        rewards = new address[](rewardsListLength);

        for (uint256 i = 0; i < rewardsListLength; ++i) {
            address reward = internalBribe.rewards(i);
            rewards[i] = reward;
        }
        return rewards;
    }

    /// @dev Converts an array to a matrix of length one for use with the Voter interface claimFees and claimBribes
    /// functions
    function arrayToMatrix(address[] memory rewards) private pure returns (address[][] memory result) {
        result = new address[][](1);
        result[0] = rewards;
    }

    /// @dev Converts an address to an array of length one for use with the Voter interface claimFees and claimBribes
    // functions
    function addressToArray(address adr) private pure returns (address[] memory result) {
        result = new address[](1);
        result[0] = adr;
    }

    function _mergeArrays(
        IERC20[] memory addressesA,
        uint256[] memory valuesA,
        IERC20[] memory addressesB,
        uint256[] memory valuesB
    ) private pure returns (uint256[] memory amountsClaimed, IERC20[] memory rewardTokens) {
        IERC20[] memory tempAddresses = new IERC20[](addressesA.length + addressesB.length);

        uint256 toRemoveCount = 0;

        IERC20[] memory mergedAddresses = _concatenateAddressesArrays(addressesA, addressesB);
        uint256[] memory mergedValues = _concatenateUint256Arrays(valuesA, valuesB);

        uint256 length = mergedAddresses.length;
        for (uint256 i = 0; i < length; ++i) {
            IERC20 currentAddress = mergedAddresses[i];

            if (_isInArray(tempAddresses, currentAddress)) {
                ++toRemoveCount;
                continue;
            }
            tempAddresses[i] = currentAddress;

            for (uint256 j = i + 1; j < mergedAddresses.length; ++j) {
                if (mergedAddresses[j] == currentAddress) {
                    mergedValues[i] += mergedValues[j];
                }
            }
        }

        uint256 mergedLength = mergedAddresses.length;

        uint256 newLength = mergedLength - toRemoveCount;
        rewardTokens = new IERC20[](newLength);
        amountsClaimed = new uint256[](newLength);

        uint256 k = 0;
        for (uint256 i = 0; i < mergedLength; ++i) {
            if (address(tempAddresses[i]) == address(0)) {
                continue;
            } else {
                rewardTokens[k] = IERC20(tempAddresses[i]);
                amountsClaimed[k] = mergedValues[i];
                ++k;
            }
        }
    }

    function _concatenateUint256Arrays(
        uint256[] memory arr1,
        uint256[] memory arr2
    ) private pure returns (uint256[] memory) {
        uint256 len1 = arr1.length;
        uint256 len2 = arr2.length;
        uint256[] memory result = new uint256[](len1 + len2);

        for (uint256 i = 0; i < len1; ++i) {
            result[i] = arr1[i];
        }

        for (uint256 i = 0; i < len2; ++i) {
            result[len1 + i] = arr2[i];
        }

        return result;
    }

    function _concatenateAddressesArrays(
        IERC20[] memory arr1,
        IERC20[] memory arr2
    ) private pure returns (IERC20[] memory) {
        uint256 len1 = arr1.length;
        uint256 len2 = arr2.length;
        IERC20[] memory result = new IERC20[](len1 + len2);

        for (uint256 i = 0; i < len1; ++i) {
            result[i] = arr1[i];
        }

        for (uint256 i = 0; i < len2; ++i) {
            result[len1 + i] = arr2[i];
        }

        return result;
    }

    function _isInArray(IERC20[] memory elements, IERC20 element) private pure returns (bool) {
        uint256 length = elements.length;
        for (uint256 i = 0; i < length; ++i) {
            if (elements[i] == element) {
                return true;
            }
        }
        return false;
    }

    function _getContractAddress() private view returns (address) {
        // slither-disable-next-line var-read-using-this
        return this.getContractAddress();
    }

    /**
     * @dev This function adds an extra STATICCALL, but it is very helpful for testing purposes.
     *  The function can be easily mocked to impersonate user calls
     */
    function getContractAddress() public view returns (address) {
        return address(this);
    }
}
