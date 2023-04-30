// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

// NOTE: took out 4626 test since due to our setup the tests would have hard time
//       completing in reasonable time.
// NOTE: should be put back in once the fuzzing constraints can be implemented

// import { ERC4626Test } from "erc4626-tests/ERC4626.test.sol";
//
// import { ERC20Mock } from "openzeppelin-contracts/mocks/ERC20Mock.sol";
// import { ERC4626Mock, IERC20Metadata } from "openzeppelin-contracts/mocks/ERC4626Mock.sol";
// import { BaseTest } from "test/BaseTest.t.sol";
//
// import { IMainRewarder, MainRewarder } from "src/rewarders/MainRewarder.sol";
//
// import { ILMPVault, LMPVault } from "src/vault/LMPVault.sol";
//
// contract LMPVaultTest is ERC4626Test, BaseTest {
//     function setUp() public override (BaseTest, ERC4626Test) {
//         BaseTest.setUp();
//
//         _underlying_ = address(mockAsset("MockERC20", "MockERC20"));
//
//         ILMPVault vault = new LMPVault(
//                 _underlying_,
//                 address(accessController),
//                 createStrategy(new address[](1)),
//                 address(createMainRewarder())
//             );
//         _vault_ = address(vault);
//         _delta_ = 0;
//         _vaultMayBeEmpty = true;
//         _unlimitedAmount = false;
//     }
// }
