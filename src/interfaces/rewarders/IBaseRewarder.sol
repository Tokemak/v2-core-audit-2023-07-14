// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IBaseRewarder {
    error UnAuthorized();
    error OperatorOnly();
    error StakeTrackerOnly();
    error RewardManagerOnly();
    error ZeroAddress();
    error ZeroAmount();

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    /**
     * @notice Claims and transfers all rewards for the specified account
     */
    function getReward() external;

    /**
     * @notice Stakes the specified amount of tokens for the specified account.
     * @param account The address of the account to stake tokens for.
     * @param amount The amount of tokens to stake.
     */
    function stake(address account, uint256 amount) external;

    /**
     * @dev Calculate the earned rewards for an account.
     * @param account Address of the account.
     * @return The earned rewards for the given account.
     */
    function earned(address account) external view returns (uint256);

    /**
     * @dev Calculate the reward per token.
     * @return The calculated reward per token.
     */
    function rewardToken() external view returns (address);

    /**
     * @dev Get the current reward rate per block.
     * @return The current reward rate per block.
     */
    function rewardRate() external view returns (uint256);

    /**
     * @dev Get the last block where rewards are applicable.
     * @return The last block number where rewards are applicable.
     */
    function lastBlockRewardApplicable() external view returns (uint256);

    /**
     * @dev Proxy function to get the balance of an account from the StakeTracking contract
     * @param account Address of the account.
     * @return The balance of staked tokens for the given account.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Proxy function to get the total supply of staked tokens from the StakeTracking contract
     * @return The total supply of staked tokens.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Set the duration of reward distribution in blocks.
     * @param _durationInBlock The duration in blocks.
     */
    function setDurationInBlock(uint256 _durationInBlock) external;

    /**
     * @dev Queue new rewards to be distributed.
     * @param newRewards The amount of new rewards to be queued.
     */
    function queueNewRewards(uint256 newRewards) external;
}
