// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IDestinationAdapter } from "./IDestinationAdapter.sol";

/**
 * @title IStakingAdapter
 * @dev This is an interface to mark adapters as ones that are dedicated for LPs staking and to be registered in
 *      Destination Registry. It doesn't contain any functions as staking interfaces usually are protocol-specific.
 */
interface IStakingAdapter is IDestinationAdapter { }
