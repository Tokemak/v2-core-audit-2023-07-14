// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract BaseTest is Test {
    mapping(bytes => address) internal _tokens;

    // -- tokens -- //
    IERC20 public usdc;
    IERC20 public toke;

    function setUp() public virtual {
        // TODO: export addresses to separate config
        _tokens["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        _tokens["TOKE"] = 0x2e9d63788249371f1DFC918a52f8d799F4a38C94;

        toke = IERC20(_tokens["TOKE"]);
        usdc = IERC20(_tokens["USDC"]);
    }
}
