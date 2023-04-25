// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ConvexAdapter } from "./ConvexAdapter.sol";

/**
 * @title AuraAdapter
 * @dev This contract implements an adapter for interacting with Aura's reward system.
 * We're using a Convex Adapter as Aura uses the Convex interfaces for LPs staking.
 */
contract AuraAdapter is ConvexAdapter { }
