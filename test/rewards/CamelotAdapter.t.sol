// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import { CamelotAdapter } from "../../src/rewards/CamelotAdapter.sol";
import { IClaimableRewards } from "../../src/interfaces/rewards/IClaimableRewards.sol";
import { INFTPool } from "../../src/interfaces/external/camelot/INFTPool.sol";
import { XGRAIL_ARBITRUM, GRAIL_ARBITRUM } from "../utils/Addresses.sol";
import { CamelotBase } from "../base/CamelotBase.sol";

// solhint-disable func-name-mixedcase
contract CamelotAdapterTest is CamelotBase {
    IERC20 private grailToken = IERC20(GRAIL_ARBITRUM);
    IERC20 private xGrailToken = IERC20(XGRAIL_ARBITRUM);

    CamelotAdapter private adapter;

    function setUp() public {
        string memory endpoint = vm.envString("ARBITRUM_MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(endpoint, 65_803_040);
        vm.selectFork(forkId);

        adapter = new CamelotAdapter(grailToken, xGrailToken);
    }

    function test_Revert_IfAddressZero() public {
        vm.expectRevert(IClaimableRewards.TokenAddressZero.selector);
        adapter.claimRewards(address(0));
    }

    // pool ETH-USDC
    function test_claimRewards_PoolETH_USDC() public {
        address whale = 0xEfe609f34A17C919118C086F81d61ecA579AB2E7;
        address nftPoolAddress = 0x6BC938abA940fB828D39Daa23A94dfc522120C11;
        vm.startPrank(whale);
        transferNFTsTo(nftPoolAddress, whale, address(adapter));
        vm.stopPrank();

        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(nftPoolAddress);

        assertEq(rewardsToken.length, 2);
        assertEq(address(rewardsToken[0]), GRAIL_ARBITRUM);
        assertEq(address(rewardsToken[1]), XGRAIL_ARBITRUM);
        assertTrue(amountsClaimed[0] > 0);
        assertTrue(amountsClaimed[1] > 0);
    }

    // pool ETH-wstETH
    function test_claimRewards_PoolWETHwstETH() public {
        address whale = 0xfF2BDf4dbf09175e615f2A27bCF3890B3a29CFf8;
        address nftPoolAddress = 0x32B18B8ccD84983C7ddc14c215A42caC098BA714;

        vm.startPrank(whale);
        transferNFTsTo(nftPoolAddress, whale, address(adapter));
        vm.stopPrank();

        (uint256[] memory amountsClaimed, IERC20[] memory rewardsToken) = adapter.claimRewards(nftPoolAddress);

        assertTrue(rewardsToken.length == 2);
        assertEq(rewardsToken.length, 2);
        assertEq(address(rewardsToken[0]), GRAIL_ARBITRUM);
        assertEq(address(rewardsToken[1]), XGRAIL_ARBITRUM);
        assertTrue(amountsClaimed[0] > 0);
        assertTrue(amountsClaimed[1] > 0);
    }
}
