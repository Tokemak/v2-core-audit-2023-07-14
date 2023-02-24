// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable2Step as OZOwnable2Step } from "openzeppelin-contracts/access/Ownable2Step.sol";

abstract contract Ownable2Step is OZOwnable2Step {
    function renounceOwnership() public view override onlyOwner {
        revert("cannot renounce ownership");
    }
}
