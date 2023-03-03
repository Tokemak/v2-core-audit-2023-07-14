// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC4626 } from "openzeppelin-contracts/interfaces/IERC4626.sol";
import { IERC20Permit } from "openzeppelin-contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

interface IPlasmaPool is IERC4626, IERC20Permit {
    error TokenAddressZero();
    error ERC4626MintExceedsMax(uint256 shares, uint256 maxMint);
}
