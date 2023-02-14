# Tokemak Pricing System

This part of the Tokemak GP system is meant to be a general purpose pricing system for any ERC20 compliant token. Other contracts in the Tokemak GP system will interface with this cluster of contracts using the `EthValueOracle.getPrice(address tokenToPrice, uint256 amount)` function.

## `ValueProvider.sol` Contract Code Requirements

Each `ValueProvider.sol` contract must inherit from `BaseValueProvider.sol`. This contract contains a `getPrice(address tokenToPrice)` function that must be implemented in each value provider contract. Each `ValueProvider.getPrice()` function must use the `onlyValueOracle` modifier. This is a security measure, making sure that pricing can only be accessed through the `EthValueOracle.sol` contract.

Each `ValueProvider.sol` contract must return the price of a single token in 18 decimals of precision. Failure to do this will cause values that are off by orders of magnitude to be returned to external callers. The `TokemakPricingPrecision.sol` library provides helper functions for precision math.

## Integration Testing

Each pool added to the system should be tested in `EthValueOracleIntegrationTest.sol`. This is generally good practice, and will prevent any unexpectedly incompatible pools from being put into production with the system.
