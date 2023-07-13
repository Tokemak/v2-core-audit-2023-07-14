# Tokemak Destination Adapters Docs

## Destination Adapters

-   Destination Adapters are basically the libraries used by Destination Vaults and potentially in other parts of system for managing liquidity deployment/withdrawal process and claiming rewards from staking.

-   Each Adapter targets specific exchange and aims to support one of the three basic operations: to provide liquidity, withdraw or manage the rewards (claiming).

-   With the simple interface and very low knowledge of the details of particular exchange it's possible to easily achieve those operations and target liquidity to a needed space.

-   They also responsible for validating the calculations of received asset deltas after the operation, but do not handle any system-wide numbers and limited to their scope, so they do not persist any state and all the operations are atomic (some exchanges require to hold NFTs representing the position in the protocol, but that do not affects Adapters executions).
