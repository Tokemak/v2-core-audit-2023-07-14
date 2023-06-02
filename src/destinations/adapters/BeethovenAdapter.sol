// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { BalancerV2MetaStablePoolAdapter } from "./BalancerV2MetaStablePoolAdapter.sol";

import { IVault } from "../../interfaces/external/balancer/IVault.sol";

/**
 * @title BeethovenAdapter
 * @dev This contract implements an adapter for interacting with Beethoven X's system.
 * We're using Balancer Adapter's interfaces for this purpose as Beethoven is a Balancer fork.
 */
contract BeethovenAdapter is BalancerV2MetaStablePoolAdapter { }
