// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IPool.sol";

interface ICryptoSwapPool is IPool {
    /* solhint-disable func-name-mixedcase, var-name-mixedcase */
    function add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) external;

    function remove_liquidity(uint256 amount, uint256[] memory min_amounts) external;

    function remove_liquidity_one_coin(uint256 token_amount, uint256 i, uint256 min_amount) external;
}
