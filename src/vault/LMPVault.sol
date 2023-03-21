// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PlasmaVault } from "./PlasmaVault.sol";
import { ILMPVault } from "src/interfaces/vault/ILMPVault.sol";
import { IDestinationVault } from "src/interfaces/vault/IDestinationVault.sol";
import { IStrategy } from "src/strategy/IStrategy.sol";
import { Ownable } from "openzeppelin-contracts/access/Ownable.sol";
import { IERC4626 } from "openzeppelin-contracts/interfaces/IERC4626.sol";

// TODO: set deposit limit: a) method b) role c) events

contract LMPVault is ILMPVault, PlasmaVault, Ownable {
    constructor(address _vaultAsset) PlasmaVault(_vaultAsset) { }

    IStrategy public strategy;

    uint256 public totalIdle = 0;
    // slither-disable-next-line constable-states
    uint256 public totalDebt = 0;

    function totalAssets() public view override (PlasmaVault, IERC4626) returns (uint256) {
        return totalIdle + totalDebt;
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override (PlasmaVault, IERC4626) whenNotPaused nonReentrant returns (uint256 shares) {
        // make sure we have strategy set
        if (address(strategy) == address(0)) revert StrategyNotSet();

        // process deposit / get funds in from sender
        shares = super.deposit(assets, receiver);

        //         // query strategy for destinations and amounts
        //         (address[] memory destinationVaults, uint256[] memory amounts) = strategy.getDepositBreakup(assets);
        //
        //         // deposit in destinations (with self as depositor)
        //         for (uint256 i = 0; i < destinationVaults.length; ++i) {
        //             IDestinationVault(destinationVaults[i]).deposit(amounts[i], address(this));
        //         }

        // add to idle funds counter
        totalIdle += assets;
    }

    function mint(
        uint256 shares,
        address receiver
    ) public virtual override (PlasmaVault, IERC4626) whenNotPaused nonReentrant returns (uint256 assets) {
        // do main mint
        assets = super.mint(shares, receiver);

        // increment totalIdle
        totalIdle += assets;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override (PlasmaVault, IERC4626) whenNotPaused nonReentrant returns (uint256 shares) {
        // first try direct withdrawal from "idle" assets since that's immediately available
        if (totalIdle > 0) {
            // get amount to withdraw from idle
            uint256 idleAssetsToWithdraw = assets <= totalIdle ? assets : totalIdle;

            // subtract it from outstanding
            assets -= idleAssetsToWithdraw;
            // slither-disable-next-line events-maths
            totalIdle -= idleAssetsToWithdraw;

            // do the withdrawal
            shares = super.withdraw(idleAssetsToWithdraw, receiver, owner);
        }

        // if we still have outstanding funds to withdraw, only then go to strategies
        uint256 assetsToWithdraw = assets;
        if (assets > 0) {
            // query strategy for destinations and amounts
            (address[] memory destinationVaults, uint256[] memory amounts) = strategy.getDepositBreakup(assets);

            // withdraw from destinations to here
            // TODO: should we just send it all back in one shot?
            for (uint256 i = 0; i < destinationVaults.length; ++i) {
                // slither-disable-next-line calls-loop
                assetsToWithdraw -=
                    IDestinationVault(destinationVaults[i]).withdraw(amounts[i], address(this), address(this));
            }

            // process caller's withdraw / send back funds
            shares += super.withdraw(assets, receiver, owner);
        }

        // if after going round robin we still have outstanding funds to withdraw, then we failed
        if (assetsToWithdraw > 0) revert WithdrawalIncomplete();
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override (PlasmaVault, IERC4626) whenNotPaused nonReentrant returns (uint256 assets) {
        // TODO:    figure out if asset approach here is ok, since we don't know the
        //          number of shares that remote vaults will give us!
        // get amount of assets needed to satisfy shares
        assets = previewRedeem(shares);

        // first try direct withdrawal from "idle" assets since that's immediately available
        if (totalIdle > 0) {
            // get amount to withdraw from idle
            uint256 idleAssetsToWithdraw = assets <= totalIdle ? assets : totalIdle;

            // subtract it from outstanding
            assets -= idleAssetsToWithdraw;
            totalIdle -= idleAssetsToWithdraw;

            // do the withdrawal
            shares = super.withdraw(idleAssetsToWithdraw, receiver, owner);
        }

        // if we still have outstanding funds to withdraw, only then go to strategies
        uint256 assetsToWithdraw = assets;
        if (assets > 0) {
            // query strategy for destinations and amounts
            (address[] memory destinationVaults, uint256[] memory amounts) = strategy.getDepositBreakup(assets);

            // withdraw from destinations to here
            // TODO: should we just send it all back in one shot?
            for (uint256 i = 0; i < destinationVaults.length; ++i) {
                // slither-disable-next-line calls-loop
                assetsToWithdraw -=
                    IDestinationVault(destinationVaults[i]).withdraw(amounts[i], address(this), address(this));
            }

            // process caller's withdraw / send back funds
            shares += super.withdraw(assets, receiver, owner);
        }

        // if after going round robin we still have outstanding funds to withdraw, then we failed
        if (assetsToWithdraw > 0) revert WithdrawalIncomplete();

        _burnTransfer(assets, shares, receiver, owner, true);
    }

    function setStrategy(IStrategy _strategy) public onlyOwner {
        strategy = _strategy;
        emit StrategySet(address(_strategy));
    }
}
