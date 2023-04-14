// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IClaimableRewards } from "./IClaimableRewards.sol";

interface IVaultClaimableRewards is IClaimableRewards {
    /**
     * @notice Claim rewards
     * @return amountsClaimed The amounts of rewards claimed
     * @return tokens The tokens that rewards were claimed for
     */
    function claimRewards() external returns (uint256[] memory, IERC20[] memory);
}
