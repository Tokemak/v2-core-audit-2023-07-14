// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { INFTPool } from "src/interfaces/external/camelot/INFTPool.sol";

/// @notice  This contract is used to test Camelot contracts.
abstract contract CamelotBase is Test {
    function getNFTs(address whale, address nftPoolAddress) public view returns (uint256[] memory) {
        INFTPool nftPool = INFTPool(nftPoolAddress);
        uint256 length = nftPool.balanceOf(whale);
        uint256[] memory tokenIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = nftPool.tokenOfOwnerByIndex(whale, i);
            tokenIds[i] = tokenId;
        }
        return tokenIds;
    }

    function transferNFTsTo(address nftPoolAddress, address from, address to) public {
        INFTPool nftPool = INFTPool(nftPoolAddress);
        uint256[] memory tokenIds = getNFTs(from, nftPoolAddress);
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length; i++) {
            nftPool.transferFrom(from, to, tokenIds[i]);
        }
    }

    function increase1Week() public {
        // Move 7 days later
        vm.roll(block.number + 7200 * 7);
        // solhint-disable-next-line not-rely-on-time
        vm.warp(block.timestamp + 7 days);
    }
}
