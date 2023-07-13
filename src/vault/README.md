# Tokemak Vaults Docs

## Destination Vaults

Destination Vaults are vaults that sit in front of any place we may be deploying assets. These vaults act as a common interface to these various places allowing us to hide the intricacies of DeFi from the rest of the system. These vaults also hold any receipt tokens we receive from these deployments. These are not 4626 vaults.

To facilitate the testing of these vaults, each type of destination has an explicitly defined contract in our code base. These are top-level contracts with minimal code, with the majority of the functionality being accessed from the Destination Vault contracts and Adapter libraries.

Destination Vaults mint shares on 1:1 proportion against their underlyer and they're priced in terms of Vault's "base asset".

Every new Vault should be based on `src/vault/DestinationVault.sol` which encapsulates all the common functionality and gives the ability to child contracts to define the details of integrating with the specific exchanges. Destination Vaults usually combine two sources of operating destinations: the base layer of depositing (usually a pool) and LP staking part. E.g. in `CurveConvexDestinationVault` we operate with assets deployed to Curve and manage the rewards from staking Curve LPs to Convex.

### Tracked Tokens

Vaults treat tokens that they “track” different than other tokens. “Tracked” tokens are those that make up it’s core functionality. For example, if a Destination Vault is targeting a stETH/rETH DEX pool, then the LP token of that pool, stETH, and rETH would all be considered “tracked” tokens. Additionally, the “base asset” for the vault, in our MVP case WETH, falls into this category.

### Data

-   `idle` - This is the amount of the base asset that is currently in the vault
-   `debt` - This is the amount of the base asset that has been transferred away from Vault in service of a deployment.
    -   For example, if the Vault contained 100 idle WETH and we decided to deploy the entire lot, idle would go to 0, and debt would go to 100
