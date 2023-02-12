// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./value-providers/IBaseValueProvider.sol";
import "./IEthValueOracle.sol";

import "../../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract EthValueOracle is IEthValueOracle, Ownable {
    function addProvider(address provider) external onlyOwner { }
}
