// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface INFTHandler {
    function onNFTHarvest(
        address operator,
        address to,
        uint256 tokenId,
        uint256 grailAmount,
        uint256 xGrailAmount
    ) external returns (bool);
}
