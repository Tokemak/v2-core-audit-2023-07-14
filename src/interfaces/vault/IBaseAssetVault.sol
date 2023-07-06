// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20Metadata as IERC20 } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IBaseAssetVault {
    /// @notice Asset that this Vault primarily manages
    /// @dev Vault decimals should be the same as the baseAsset
    function baseAsset() external view returns (address);
}
