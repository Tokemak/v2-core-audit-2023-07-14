// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20, SafeERC20 } from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import { IVault } from "src/interfaces/external/balancer/IVault.sol";
import { IAsset } from "src/interfaces/external/balancer/IAsset.sol";
import { ISyncSwapper } from "src/interfaces/swapper/ISyncSwapper.sol";

// TODO: access control??
contract BalancerV2Swap is ISyncSwapper {
    using SafeERC20 for IERC20;

    IVault public immutable vault;

    error PoolsMustMatchLPTokens();
    error PoolNotFound();
    error VaultAddressZero();

    constructor(address balancerVault) {
        if (balancerVault == address(0)) revert VaultAddressZero();
        vault = IVault(balancerVault);
    }

    /// @inheritdoc ISyncSwapper
    function swap(
        address,
        address sellTokenAddress,
        uint256 sellAmount,
        address buyTokenAddress,
        uint256 minBuyAmount,
        bytes memory data
    ) external override returns (uint256 actualBuyAmount) {
        bytes32 poolId = abi.decode(data, (bytes32));

        IVault.SingleSwap memory singleSwap = IVault.SingleSwap(
            poolId, IVault.SwapKind.GIVEN_IN, IAsset(sellTokenAddress), IAsset(buyTokenAddress), sellAmount, ""
        );

        IVault.FundManagement memory funds = IVault.FundManagement(address(this), false, payable(address(this)), false);

        IERC20(sellTokenAddress).safeApprove(address(vault), sellAmount);

        // slither-disable-next-line timestamp
        // solhint-disable-next-line not-rely-on-time
        return vault.swap(singleSwap, funds, minBuyAmount, block.timestamp);
    }
}
