// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interfaces/pricing/IBaseValueProvider.sol";
import "../interfaces/pricing/IEthValueOracle.sol";

import "openzeppelin-contracts/access/Ownable.sol";

contract EthValueOracle is IEthValueOracle, Ownable {
    function addProvider(address provider) external onlyOwner { }
}
