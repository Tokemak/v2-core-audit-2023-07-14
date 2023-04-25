// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title IDestinationAdapter
 * @dev This is a base interface for differnt types of adapters to be registered in Destination Registry.
 */
interface IDestinationAdapter {
    error MustBeMoreThanZero();
    error ArraysLengthMismatch();
    error BalanceMustIncrease();
    error MinLpAmountNotReached();
    error LpTokenAmountMismatch();
    error NoNonZeroAmountProvided();
    error InvalidBalanceChange();
    error InvalidAddress(address);
}
