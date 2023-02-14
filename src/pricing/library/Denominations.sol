// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Taken from: https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/Denominations.sol

library Denominations {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address public constant STETH_MAINNET = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    // Placeholder used in unique situation where eth needs to be priced in USD.
    //    This is only applicable when an asset's price is only available in USD,
    //    `BaseValueProviderDenominations.sol` contract will get Eth in USD as well as
    //    asset price in USD in order to convert the price to an eth quote.  In all
    //    other parts of the system we want eth to be priced as 1e18.
    address public constant ETH_IN_USD = address(bytes20("ETH_IN_USD"));

    // Fiat currencies follow https://en.wikipedia.org/wiki/ISO_4217
    address public constant USD = address(840);
    address public constant GBP = address(826);
    address public constant EUR = address(978);
    address public constant JPY = address(392);
    address public constant KRW = address(410);
    address public constant CNY = address(156);
    address public constant AUD = address(36);
    address public constant CAD = address(124);
    address public constant CHF = address(756);
    address public constant ARS = address(32);
    address public constant PHP = address(608);
    address public constant NZD = address(554);
    address public constant SGD = address(702);
    address public constant NGN = address(566);
    address public constant ZAR = address(710);
    address public constant RUB = address(643);
    address public constant INR = address(356);
    address public constant BRL = address(986);
}
