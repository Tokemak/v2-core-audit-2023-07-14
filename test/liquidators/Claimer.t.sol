// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// solhint-disable func-name-mixedcase
import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { Claimer } from "../../src/liquidation/Claimer.sol";
import { IAsyncSwapper } from "../../src/interfaces/liquidation/IAsyncSwapper.sol";
import { IClaimer } from "../../src/interfaces/liquidation/IClaimer.sol";
import { IVaultClaimableRewards } from "../../src/interfaces/rewards/IVaultClaimableRewards.sol";

contract MockVault is IVaultClaimableRewards {
    function claimRewards() external override returns (uint256[] memory, IERC20[] memory) {
        // delegatecall the Reward Adapater associated to it
    }
}

contract ClaimerTest is Test {
    Claimer private claimer;

    function setUp() public {
        claimer = new Claimer();
    }

    function test_Revert_claimRewards_IfAVaultHasZeroAddress() public {
        IVaultClaimableRewards[] memory vaults = new IVaultClaimableRewards[](1);
        vaults[0] = IVaultClaimableRewards(address(0));

        vm.expectRevert(IClaimer.ZeroAddress.selector);
        claimer.claimsVaultRewards(vaults);
    }

    function test_claimRewards() public {
        IVaultClaimableRewards[] memory vaults = new IVaultClaimableRewards[](2);
        vaults[0] = IVaultClaimableRewards(new MockVault());
        vaults[1] = IVaultClaimableRewards(new MockVault());

        vm.expectCall(address(vaults[0]), abi.encodeCall(vaults[0].claimRewards, ()));
        vm.expectCall(address(vaults[1]), abi.encodeCall(vaults[0].claimRewards, ()));

        claimer.claimsVaultRewards(vaults);
    }
}
