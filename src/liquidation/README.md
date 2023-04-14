## Claim Rewards

The primary goal of this process is to claim rewards for each Vault. Once rewards are claimed, they are sent to the Liquidator Row contract for subsequent liquidation.

Sequence diagram: https://app.diagrams.net/#G1tO09VdO5BIaHqEBGVZ2ld6wF_25szZdj

### Process

The Autotask cloud function is triggered and performs the following steps:

-   Calls the Claimer contract with the list of Vault addresses.
-   The Claimer contract iterates through each Vault address and calls the claimRewards function.

For each Vault, the claimRewards function performs the following steps:

-   Calls the RewardAdapter's claimRewards function, which claims the rewards from the external pool contract (e.g., Convex, Curve, or Balancer).
-   For each claimed asset:
    -   Transfers the claimed rewards to the Liquidator Row contract using IERC20(claimedAsset).transfer(liquidatorRow, amount).
    -   Calls the Liquidator Row's updateBalances function to update the balance information for the claimed assets.

After the claiming process, the liquidation process takes place, which converts the claimed assets into a target asset (e.g., WETH) and updates the Vault balances accordingly.

### Components

#### Claimer

The Claimer contract acts as an orchestrator for the claiming process. Its primary function is to trigger the claimRewards function for each Vault contract provided in the parameter.

#### Vaults

Each Vault must implement the IVaultClaimableRewards interface and have a claimRewards function that performs the following steps:

-   Call rewardAdapter.claimRewards(...) to claim the rewards from the connected AMM protocol, such as Convex, Curve, or Balancer.
-   For each claimed asset:
    a. Use IERC20(claimedAsset).transfer(liquidatorRow, amount) to transfer the claimed asset to the Liquidator Row contract.
    b. Call liquidationRow.updateBalances(...) to update the balances of the claimed assets in the Liquidator Row contract.

#### Rewards Adapter

This component implements the IClaimableRewardsAdapter interface and serves as a bridge between the main smart contract (like the Vault) and External Pool Contracts. It standardizes the interaction with different AMM protocols and allows the Vault to claim rewards on behalf of users.

#### Liquidator Row

The Liquidator Row is the smart contract responsible for liquidating reward tokens into another asset, such as WETH. After the Vault claims rewards using the RewardAdapter, it transfers the rewards to the Liquidator Row. The Liquidator Row maintains a record of each vault's balances, enabling it to accurately distribute the liquidated assets (e.g., WETH) back to the appropriate vaults in proportion to their respective balances.

---

## Liquidate Rewards

The primary goal of this process is to liquidate rewards for each Vault. Once rewards are claimed and sent to the Liquidator Row contract, they are liquidated into another asset, such as WETH.

Sequence diagram: https://app.diagrams.net/#G1s_vQgDn0cFG4PZSY_pkKUzk31h23Vs6k

### Process

The Autotask cloud function is triggered and performs the following steps:

-   Calls the Liquidator Row contract to get the list of tokens to liquidate.
-   For each token, it calls:
    a. The aggregator API to get the best swap for the given token.
    b. The Liquidator Row contract to liquidate rewards.

The Liquidator Row contract:

-   Calls the Swapper contract to swap the token against the target token (which in turn calls an external aggregator).
-   Calls the Pricing contract to determine if the swap was successful.
-   Transfers the swapped assets back to the respective Vaults and updates their balances accordingly.

### Components

#### Liquidator Row

The Liquidator Row contract acts as an orchestrator for the liquidation process. Its primary function is to trigger the liquidateRewards function for each Vault contract provided in the parameter.

#### Swapper

The Swapper contract is responsible for performing the actual swap of claimed assets into another asset, such as WETH. It interacts with external aggregators to find the best swap route and execute the token swap.
