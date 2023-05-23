// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { DestinationVault } from "src/vault/DestinationVault.sol";
import { IERC20, ERC20 } from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { EnumerableSet } from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

contract TestDestinationVault is DestinationVault {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private _debtVault;
    uint256 private _rewardValue;
    uint256 private _claimVested;
    uint256 private _reclaimDebtAmount;
    uint256 private _reclaimDebtLoss;
    EnumerableSet.AddressSet private _trackedTokens;

    constructor(address token) {
        initialize(ISystemRegistry(address(0)), IERC20Metadata(token), "ABC", abi.encode(""));
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function debtValue() public view override returns (uint256 value) {
        return _debtVault;
    }

    function rewardValue() public view override returns (uint256 value) {
        return _rewardValue;
    }

    function claimVested_() internal view override returns (uint256 amount) {
        return _claimVested;
    }

    function isTrackedToken_(address token) internal view override returns (bool) {
        return _trackedTokens.contains(token);
    }

    function reclaimDebt_(uint256, uint256) internal view override returns (uint256 amount, uint256 loss) {
        return (_reclaimDebtAmount, _reclaimDebtLoss);
    }

    function setDebtValue(uint256 val) public {
        _debtVault = val;
    }

    function setRewardValue(uint256 val) public {
        _rewardValue = val;
    }

    function setClaimVested(uint256 val) public {
        _claimVested = val;
    }

    function setReclaimDebtAmount(uint256 val) public {
        _reclaimDebtAmount = val;
    }

    function setReclaimDebtLoss(uint256 val) public {
        _reclaimDebtLoss = val;
    }

    function setDebt(uint256 val) public {
        debt = val;
    }

    function reset() external { }
}
