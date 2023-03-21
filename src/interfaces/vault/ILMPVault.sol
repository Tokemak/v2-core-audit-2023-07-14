// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPlasmaVault } from "./IPlasmaVault.sol";
import { IStrategy } from "src/strategy/IStrategy.sol";

interface ILMPVault is IPlasmaVault {
    event StrategySet(address strategy);

    error StrategyNotSet();
    error WithdrawalFailed();
    error DepositFailed();
    error WithdrawalIncomplete();

    function strategy() external view returns (IStrategy);

    function setStrategy(IStrategy _strategy) external;
}
