// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/console.sol";
import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { Liquidator } from "../../src/liquidators/Liquidator.sol";
import { ISwapper } from "../../src/interfaces/liquidators/ISwapper.sol";
import { ILiquidable, SwapperParams } from "../../src/interfaces/liquidators/ILiquidable.sol";
import { ILiquidator } from "../../src/interfaces/liquidators/ILiquidator.sol";
import { IPlasmaPoolClaimableRewards } from "../../src/interfaces/rewards/IPlasmaPoolClaimableRewards.sol";

contract MockVault is IPlasmaPoolClaimableRewards, ILiquidable {
    function claimRewards() external override returns (uint256[] memory, IERC20[] memory) {
        // delegatecall the Reward Adapater associated to it
    }

    function liquidate(SwapperParams memory swapperParams) external override {
        // delegatecall to the Swapper given in the params
        /*
        ISWapper(swapperParams.swapperAddress).swap(
            swapperParams.sellTokenAddress,
            swapperParams.sellAmount,
            swapperParams.buyTokenAddress,
            swapperParams.buyAmount,
            swapperParams.data
        );
        */
    }
}

contract LiquidatorTest is Test {
    Liquidator private liquidator;

    function setUp() public {
        liquidator = new Liquidator();
    }

    function test_Revert_claimRewards_IfAVaultHasZeroAddress() public {
        IPlasmaPoolClaimableRewards[] memory vaults = new IPlasmaPoolClaimableRewards[](1);
        vaults[0] = IPlasmaPoolClaimableRewards(address(0));

        vm.expectRevert(ILiquidator.ZeroAddress.selector);
        liquidator.claimsVaultRewards(vaults);
    }

    function test_Revert_liquidate_IfAVaultHasZeroAddress() public {
        ILiquidable[] memory vaults = new ILiquidable[](1);
        vaults[0] = ILiquidable(address(0));

        SwapperParams[] memory swapperParamsList = new SwapperParams[](1);
        SwapperParams memory swapperParams = getTestSwapParams();
        swapperParamsList[0] = swapperParams;

        vm.expectRevert(ILiquidator.ZeroAddress.selector);
        liquidator.liquidateVaults(vaults, swapperParamsList);
    }

    function test_Revert_liquidate_IfInvalidParamsLength() public {
        ILiquidable[] memory vaults = new ILiquidable[](2);
        vaults[0] = ILiquidable(address(0));
        vaults[1] = ILiquidable(address(0));

        SwapperParams[] memory swapperParamsList = new SwapperParams[](1);
        SwapperParams memory swapperParams = getTestSwapParams();
        swapperParamsList[0] = swapperParams;

        vm.expectRevert(ILiquidator.InvalidParamsLength.selector);
        liquidator.liquidateVaults(vaults, swapperParamsList);
    }

    function test_claimRewards() public {
        IPlasmaPoolClaimableRewards[] memory vaults = new IPlasmaPoolClaimableRewards[](2);
        vaults[0] = IPlasmaPoolClaimableRewards(new MockVault());
        vaults[1] = IPlasmaPoolClaimableRewards(new MockVault());

        vm.expectCall(address(vaults[0]), abi.encodeCall(vaults[0].claimRewards, ()));
        vm.expectCall(address(vaults[1]), abi.encodeCall(vaults[0].claimRewards, ()));

        liquidator.claimsVaultRewards(vaults);
    }

    function test_liquidate() public {
        ILiquidable[] memory vaults = new ILiquidable[](2);
        vaults[0] = ILiquidable(new MockVault());
        vaults[1] = ILiquidable(new MockVault());

        SwapperParams[] memory swapperParamsList = new SwapperParams[](2);
        SwapperParams memory swapperParams = getTestSwapParams();
        swapperParamsList[0] = swapperParams;
        swapperParamsList[1] = swapperParams;

        vm.expectCall(address(vaults[0]), abi.encodeCall(vaults[0].liquidate, (swapperParams)));
        vm.expectCall(address(vaults[1]), abi.encodeCall(vaults[0].liquidate, (swapperParams)));

        liquidator.liquidateVaults(vaults, swapperParamsList);
    }

    function getTestSwapParams() public pure returns (SwapperParams memory) {
        return SwapperParams({
            swapperAddress: address(0),
            sellTokenAddress: address(0),
            sellAmount: 0,
            buyTokenAddress: address(0),
            buyAmount: 0,
            data: new bytes(0)
        });
    }
}
