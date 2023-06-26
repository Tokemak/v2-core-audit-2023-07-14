// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/security/ReentrancyGuard.sol";

import { IRewardsOnlyGauge } from "../../../interfaces/external/beethoven/IRewardsOnlyGauge.sol";
import { IChildChainStreamer } from "../../../interfaces/external/beethoven/IChildChainStreamer.sol";
import { IChildChainGaugeRewardHelper } from "../../../interfaces/external/beethoven/IChildChainGaugeRewardHelper.sol";
import { IClaimableRewardsAdapter } from "../../../interfaces/destinations/IClaimableRewardsAdapter.sol";

contract BeethovenRewardsAdapter is IClaimableRewardsAdapter, ReentrancyGuard {
    // slither-disable-start naming-convention
    // solhint-disable-next-line var-name-mixedcase
    IChildChainGaugeRewardHelper public immutable GAUGE_REWARD_HELPER;
    // slither-disable-end naming-convention

    constructor(IChildChainGaugeRewardHelper gaugeRewardHelper) {
        if (address(gaugeRewardHelper) == address(0)) revert TokenAddressZero();
        GAUGE_REWARD_HELPER = gaugeRewardHelper;
    }

    /**
     * @param gauge The gauge to claim rewards from
     */
    function claimRewards(address gauge) public nonReentrant returns (uint256[] memory, IERC20[] memory) {
        if (gauge == address(0)) revert TokenAddressZero();

        address account = address(this);

        IRewardsOnlyGauge gaugeContract = IRewardsOnlyGauge(gauge);

        IChildChainStreamer streamer = gaugeContract.reward_contract();
        uint256 count = streamer.reward_count();

        uint256[] memory balancesBefore = new uint256[](count);
        IERC20[] memory rewardTokens = new IERC20[](count);
        uint256[] memory amountsClaimed = new uint256[](count);

        // get balances before
        for (uint256 i = 0; i < count; ++i) {
            IERC20 token = streamer.reward_tokens(i);
            rewardTokens[i] = token;
            balancesBefore[i] = token.balanceOf(account);
        }

        // claim rewards
        GAUGE_REWARD_HELPER.claimRewards(gaugeContract, account);

        // get balances after and calculate amounts claimed
        for (uint256 i = 0; i < count; ++i) {
            uint256 balance = rewardTokens[i].balanceOf(account);

            uint256 claimed = balance - balancesBefore[i];
            amountsClaimed[i] = claimed;
        }

        emit RewardsClaimed(rewardTokens, amountsClaimed);

        return (amountsClaimed, rewardTokens);
    }
}
