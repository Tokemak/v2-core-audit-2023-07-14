// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { BalancerUtilities } from "src/libs/BalancerUtilities.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IAsset } from "src/interfaces/external/balancer/IAsset.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";
import { IVault as IBalancerVault } from "src/interfaces/external/balancer/IVault.sol";
import { IBalancerComposableStablePool } from "src/interfaces/external/balancer/IBalancerComposableStablePool.sol";
import { BalancerLPComposableStableEthOracle } from "src/oracles/providers/BalancerLPComposableStableEthOracle.sol";

contract BalancerLPComposableStableEthOracleTests is Test {
    IBalancerVault private constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address private constant WSTETH = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    address private constant RETH = address(0xae78736Cd615f374D3085123A210448E74Fc6393);
    address private constant SFRXETH = address(0xac3E018457B222d93114458476f3E3416Abbe38F);
    address private constant WSTETH_RETH_SFRXETH_POOL = address(0x5aEe1e99fE86960377DE9f88689616916D5DcaBe);
    address private constant UNIETH = address(0xF1376bceF0f78459C0Ed0ba5ddce976F1ddF51F4);
    address private constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address private constant UNIETH_WETH_POOL = address(0xbFCe47224B4A938865E3e2727DC34E0fAA5b1D82);

    IRootPriceOracle private rootPriceOracle;
    ISystemRegistry private systemRegistry;
    BalancerLPComposableStableEthOracle private oracle;

    uint256 private mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 17_378_951);
        vm.selectFork(mainnetFork);

        rootPriceOracle = IRootPriceOracle(vm.addr(324));
        systemRegistry = generateSystemRegistry(address(rootPriceOracle));
        oracle = new BalancerLPComposableStableEthOracle(systemRegistry, VAULT);
    }

    function testConstruction() public {
        assertEq(address(systemRegistry), address(oracle.getSystemRegistry()));
        assertEq(address(VAULT), address(oracle.balancerVault()));
    }

    function testWstETHsFRXEthrETHPool() public {
        mockRootPrice(WSTETH, 1_124_023_737_293_252_681); //wstETH
        mockRootPrice(RETH, 1_071_929_592_001_012_800); //rETH
        mockRootPrice(SFRXETH, 1_039_355_991_640_087_568); //sfrxETH

        uint256 price = oracle.getPriceEth(WSTETH_RETH_SFRXETH_POOL);

        assertEq(price > 99e16, true);
        assertEq(price < 11e17, true);
    }

    function testUsdBasedPool() public {
        mockRootPrice(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 535_370_000_000_000); //USDC
        mockRootPrice(0x6B175474E89094C44Da98b954EedeAC495271d0F, 534_820_000_000_000); //DAI
        mockRootPrice(0xdAC17F958D2ee523a2206206994597C13D831ec7, 535_540_000_000_000); //USDT

        // //solhint-disable-next-line max-line-length
        // https://app.balancer.fi/#/ethereum/pool/0x79c58f70905f734641735bc61e45c19dd9ad60bc0000000000000000000004e7
        // Pool Value at the time: $4,349,961
        // Actual Supply: 4351658.079624087001833240
        // Eth Price: $1,868.05
        uint256 price = oracle.getPriceEth(0x79c58f70905F734641735BC61e45c19dD9Ad60bC);

        assertApproxEqAbs(price, 535_109_000_000_000, 10_000_000_000_000);
    }

    function testLowestIndividualTokenPriceTokenLowersOverall() public {
        mockRootPrice(WSTETH, 1e17); //wstETH
        mockRootPrice(RETH, 1_071_929_592_001_012_800); //rETH
        mockRootPrice(SFRXETH, 1_039_355_991_640_087_568); //sfrxETH

        uint256 price = oracle.getPriceEth(WSTETH_RETH_SFRXETH_POOL);

        assertEq(price < 90e16, true);
    }

    function testReentrancyGuard() public {
        mockRootPrice(UNIETH, 1_024_023_737_293_252_681); //uniETH
        mockRootPrice(WETH, 1_024_023_737_293_252_681); //WETH

        // Runs a getPriceEth inside of a vault operation
        ReentrancyTester tester = new ReentrancyTester(oracle, address(VAULT), UNIETH, UNIETH_WETH_POOL);
        deal(UNIETH, address(tester), 10e18);
        deal(address(tester), 10e18);
        tester.run();

        assertEq(tester.getPriceFailed(), true);
        assertEq(tester.priceReceived(), type(uint256).max);
    }

    function testMissingTokensReverts() public {
        address mockPool = vm.addr(3434);
        bytes32 badPoolId = keccak256("x2349382440328");
        vm.mockCall(
            mockPool, abi.encodeWithSelector(IBalancerComposableStablePool.getPoolId.selector), abi.encode(badPoolId)
        );
        //solhint-disable-next-line max-line-length
        vm.mockCall(mockPool, abi.encodeWithSelector(IBalancerComposableStablePool.getBptIndex.selector), abi.encode(0));

        address mockVault = vm.addr(3_434_343);

        ISystemRegistry localSystemRegistry = generateSystemRegistry(address(rootPriceOracle));
        BalancerLPComposableStableEthOracle localOracle =
            new BalancerLPComposableStableEthOracle(localSystemRegistry, IBalancerVault(mockVault));

        IERC20[] memory tokens = new IERC20[](0);
        uint256[] memory amounts = new uint256[](0);
        uint256 lastChangeBlock = block.number;
        vm.mockCall(
            mockVault,
            abi.encodeWithSelector(IBalancerVault.getPoolTokens.selector),
            abi.encode(tokens, amounts, lastChangeBlock)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                BalancerLPComposableStableEthOracle.InvalidPrice.selector, mockPool, type(uint256).max
            )
        );
        localOracle.getPriceEth(mockPool);
    }

    function testInvalidPoolIdReverts() public {
        address mockPool = vm.addr(3434);
        bytes32 badPoolId = keccak256("x2349382440328");
        vm.mockCall(
            mockPool, abi.encodeWithSelector(IBalancerComposableStablePool.getPoolId.selector), abi.encode(badPoolId)
        );

        vm.expectRevert("BAL#500");
        oracle.getPriceEth(mockPool);
    }

    function testEnsureBptTokenNotPricedIn() public {
        mockRootPrice(WSTETH, 1_124_023_737_293_252_681); //wstETH
        mockRootPrice(RETH, 1_071_929_592_001_012_800); //rETH
        mockRootPrice(SFRXETH, 1_039_355_991_640_087_568); //sfrxETH
        mockRootPrice(WSTETH_RETH_SFRXETH_POOL, 10_000_039_355_991_640_087_568); //sfrxETH

        uint256 price = oracle.getPriceEth(WSTETH_RETH_SFRXETH_POOL);

        assertEq(price > 99e16, true);
        assertEq(price < 11e17, true);
    }

    function mockRootPrice(address token, uint256 price) internal {
        vm.mockCall(
            address(rootPriceOracle),
            abi.encodeWithSelector(IRootPriceOracle.getPriceEth.selector, token),
            abi.encode(price)
        );
    }

    function generateSystemRegistry(address rootOracle) internal returns (ISystemRegistry) {
        address registry = vm.addr(327_849);
        vm.mockCall(registry, abi.encodeWithSelector(ISystemRegistry.rootPriceOracle.selector), abi.encode(rootOracle));
        return ISystemRegistry(registry);
    }
}

contract ReentrancyTester {
    BalancerLPComposableStableEthOracle private oracle;
    address private balancerVault;
    address private nonWethToken;
    address private poolAddress;

    uint256 public priceReceived = type(uint256).max;
    bool public getPriceFailed = false;

    // Same as defined in BalancerUtilities
    error BalancerVaultReentrancy();

    constructor(
        BalancerLPComposableStableEthOracle _oracle,
        address _balancerVault,
        address _nonWethToken,
        address _poolAddress
    ) {
        oracle = _oracle;
        balancerVault = _balancerVault;
        nonWethToken = _nonWethToken;
        poolAddress = _poolAddress;

        IERC20(nonWethToken).approve(balancerVault, type(uint256).max);
    }

    function run() external {
        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(poolAddress);
        assets[1] = IAsset(address(0));
        assets[2] = IAsset(address(nonWethToken));

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 0;
        amounts[1] = 5e17 - 1e9;
        amounts[2] = 48_560_623_982_835_670;

        uint256[] memory amountsUser = new uint256[](2);
        amountsUser[0] = 5e17 - 1e9;
        amountsUser[1] = 48_560_623_982_835_670;

        uint256 msgValue;
        msgValue = 5e17;

        // wstETH/WETH
        IBalancerVault(balancerVault).joinPool{ value: msgValue }(
            0xbfce47224b4a938865e3e2727dc34e0faa5b1d82000000000000000000000527, //UNIETH-WETH
            address(this),
            address(this),
            IBalancerVault.JoinPoolRequest(
                assets,
                amounts,
                abi.encode(IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amountsUser, 0),
                false // Don't use internal balances
            )
        );
    }

    receive() external payable {
        if (msg.sender == balancerVault) {
            try oracle.getPriceEth(address(0x5aEe1e99fE86960377DE9f88689616916D5DcaBe)) returns (uint256 price) {
                priceReceived = price;
            } catch (bytes memory err) {
                if (keccak256(abi.encodeWithSelector(BalancerVaultReentrancy.selector)) == keccak256(err)) {
                    getPriceFailed = true;
                }
            }
        }
    }
}
