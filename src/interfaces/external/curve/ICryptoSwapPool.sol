// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IPool } from "./IPool.sol";

/* solhint-disable func-name-mixedcase, var-name-mixedcase */
interface ICryptoSwapPool is IPool {
    // slither-disable-start naming-convention
    function add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) external;

    function remove_liquidity(uint256 amount, uint256[] memory min_amounts) external;

    function remove_liquidity_one_coin(uint256 token_amount, uint256 i, uint256 min_amount) external;
    // slither-disable-end naming-convention
}
