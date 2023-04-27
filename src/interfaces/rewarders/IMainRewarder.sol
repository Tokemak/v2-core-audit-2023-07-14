// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IBaseRewarder } from "./IBaseRewarder.sol";

interface IMainRewarder is IBaseRewarder {
    /**
     * @notice Adds an ExtraRewarder contract address to the extraRewards array.
     * @param reward The address of the ExtraRewarder contract.
     */
    function addExtraReward(address reward) external;

    /**
     * @notice Withdraws the specified amount of tokens from the vault for the specified account, and transfers all
     * rewards for the account from this contract and any linked extra reward contracts.
     * @param account The address of the account to withdraw tokens and claim rewards for.
     * @param amount The amount of tokens to withdraw.
     * @param claim If true, claims all rewards for the account from this contract and any linked extra reward
     * contracts.
     */
    function withdraw(address account, uint256 amount, bool claim) external;

    /**
     * @notice Clears the extraRewards array.
     */
    function clearExtraRewards() external;

    /**
     * @notice Claims and transfers all rewards for the specified account from this contract and any linked extra reward
     * contracts.
     * @dev If claimExtras is true, also claims all rewards from linked extra reward contracts.
     * @param account The address of the account to claim rewards for.
     * @param claimExtras If true, claims rewards from linked extra reward contracts.
     */
    function getReward(address account, bool claimExtras) external;
}