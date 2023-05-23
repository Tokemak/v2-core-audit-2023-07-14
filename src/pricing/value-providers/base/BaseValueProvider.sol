// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IEthValueOracle } from "src/interfaces/pricing/IEthValueOracle.sol";
import { Errors } from "src/utils/Errors.sol";

import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";

/**
 * @title Base functionality for all `ValueProvider.sol` contracts.
 * @notice Allows access to `EthValueOracle.sol` contract for pricing queries an access restriction.
 * @dev All `ValueProvider.sol` contracts must inherit from this contract.
 */
abstract contract BaseValueProvider is Ownable {
    IEthValueOracle public ethValueOracle;

    /// @notice Used to revert when address must be address of `EthValueOracle.sol` but isn't.
    error MustBeEthValueOracle();

    /// @notice Emitted when `ethValueOracle` state variable is changed.
    event EthValueOracleSet(address ethValueOracle);

    constructor(address _ethValueOracle) Ownable() {
        setEthValueOracle(_ethValueOracle);
    }

    /**
     * @dev Used to lock external functions in `ValueProvider.sol` contracts.  This prevents
     *    users and contracts from retrieving values that may have incorrect precision from
     *    contracts that are not `EthValueOracle.sol`.  All pricing calls to this system should
     *    be forced to route through `EthValueOracle.sol`, and each new `ValueProvider.sol`
     *    contract should implement this modifier on its `getPrice()` function.
     */
    modifier onlyValueOracle() {
        if (msg.sender != address(ethValueOracle)) revert MustBeEthValueOracle();
        _;
    }

    /**
     * @dev Privileged access function.
     * @param _ethValueOracle Address of EthValueOracle.sol contract to set.
     */
    function setEthValueOracle(address _ethValueOracle) public onlyOwner {
        Errors.verifyNotZero(_ethValueOracle, "ethValueOracle");
        ethValueOracle = IEthValueOracle(_ethValueOracle);

        emit EthValueOracleSet(_ethValueOracle);
    }

    /**
     * @notice gets price of one unit of `tokenToPrice`.
     * @dev Must implement `onlyValueProvider` modifier.
     * @dev Must return values with 18 decimals of precision
     * @param tokenToPrice Address of token to price.
     * @return Price of one unit of asset in Eth.
     */
    function getPrice(address tokenToPrice) external view virtual returns (uint256);
}
