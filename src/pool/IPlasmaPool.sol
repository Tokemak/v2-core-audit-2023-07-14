// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../node_modules/@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

// solhint-disable-next-line no-empty-blocks
interface IPlasmaPool is IERC4626, IERC20Permit { }
