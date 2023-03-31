// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PlasmaVault } from "./PlasmaVault.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";

contract DestinationVault is IDestinationVault, PlasmaVault {
    constructor(address _vaultAsset, address _accessController) PlasmaVault(_vaultAsset, _accessController) { }
}
