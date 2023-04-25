# Rewards Contracts Architecture

The rewards architecture consists of three main contracts

-   MainRewarder,
-   ExtraRewarder,
-   StakeTracking.

The purpose of these contracts is to distribute rewards to users who stake their tokens.

## Summary

The StakeTracking contract keeps track of staked token balances, the MainRewarder contract distributes the main reward tokens and manages the distribution of additional reward tokens through the ExtraRewarder contracts, and the ExtraRewarder contracts distribute additional reward tokens.

## StakeTracking

The StakeTracking contract is responsible for keeping track of the total supply and balance of tokens staked by users in Vaults. It should be called by the Vaults at any liquidity moves.

It acts as a proxy between Vaults and the MainRewarder contract, monitoring the total supply and user balances of deposited tokens. This intermediary role enables accurate tracking of staking activities on multiple Vaults.

## MainRewarder

The MainRewarder contract is responsible for distributing the main reward tokens to stakers.

The operator can queue new rewards to be distributed to stakers using the queueNewRewards function. The rewards are added to a reward queue, which is then distributed to stakers based on their staked balances.

The addExtraReward function adds the address of the ExtraRewarder contract to a list of ExtraRewarder contracts that can distribute additional rewards to stakers. When a user calls the getReward function, the MainRewarder contract distributes rewards from the main reward queue and all extra reward queues. The amount of rewards distributed from each queue is proportional to the user's staked balance.

The MainRewarder contract also includes a stake and withdraw functions that allow the StakeTracking contract to keep track of liquidity moves like stake or withdraw.
When the StakeTracking contract calls the stake or withdraw function, the MainRewarder contract also calls the stake or withdraw function of any added ExtraRewarder contracts. This ensures that the user's staked balance is tracked in all associated contracts.

## ExtraRewarder

The ExtraRewarder contract is a simpler version of the MainRewarder contract and is responsible for distributing additional reward tokens to stakers.
