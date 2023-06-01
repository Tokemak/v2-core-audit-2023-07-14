// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Vm } from "forge-std/Vm.sol";
import { Roles } from "src/libs/Roles.sol";
import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { IstEth } from "src/interfaces/external/lido/IstEth.sol";
import { ISystemRegistry } from "src/interfaces/ISystemRegistry.sol";
import { IAsset } from "src/interfaces/external/balancer/IAsset.sol";
import { AccessController } from "src/security/AccessController.sol";
import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ST_ETH_CURVE_LP_TOKEN_MAINNET } from "test/utils/Addresses.sol";
import { CurveResolverMainnet } from "src/utils/CurveResolverMainnet.sol";
import { IRootPriceOracle } from "src/interfaces/oracles/IRootPriceOracle.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";
import { ICurveStableSwap } from "src/interfaces/external/curve/ICurveStableSwap.sol";
import { IVault as IBalancerVault } from "src/interfaces/external/balancer/IVault.sol";
import { ICurveMetaRegistry } from "src/interfaces/external/curve/ICurveMetaRegistry.sol";
import { CurveV1StableEthOracle } from "src/oracles/providers/CurveV1StableEthOracle.sol";

contract CurveV1StableEthOracleTests is Test {
    address private constant STETH_ETH_POOL = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
    address private constant STETH_ETH_LP_TOKEN = ST_ETH_CURVE_LP_TOKEN_MAINNET;
    IstEth private constant STETH_CONTRACT = IstEth(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    IRootPriceOracle private rootPriceOracle;
    ISystemRegistry private systemRegistry;
    AccessController private accessController;
    CurveResolverMainnet private curveResolver;
    CurveV1StableEthOracle private oracle;

    event ReceivedPrice();

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 17_379_099);
        vm.selectFork(mainnetFork);

        systemRegistry = ISystemRegistry(vm.addr(327_849));
        rootPriceOracle = IRootPriceOracle(vm.addr(324));
        accessController = new AccessController(address(systemRegistry));
        generateSystemRegistry(address(systemRegistry), address(accessController), address(rootPriceOracle));
        curveResolver = new CurveResolverMainnet(ICurveMetaRegistry(0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC));
        oracle = new CurveV1StableEthOracle(systemRegistry, curveResolver);

        // Ensure the onlyOwner call passes
        accessController.grantRole(0x00, address(this));
    }

    function testStEthEthPrice() public {
        // Pool total USD: $1,147,182,216.20
        // Eth Price: 1866.93
        // Total Supply: 571879.785719421763346624
        // https://curve.fi/#/ethereum/pools/steth/deposit

        mockRootPrice(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 1e18); //ETH
        mockRootPrice(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84, 999_193_420_000_000_000); //stETH

        oracle.registerPool(STETH_ETH_POOL, STETH_ETH_LP_TOKEN, true);

        uint256 price = oracle.getPriceEth(STETH_ETH_LP_TOKEN);

        assertApproxEqAbs(price, 1_070_000_000_000_000_000, 5e16);
    }

    function testUsdPool() public {
        // Pool Total USD: $394,742,587.16
        // Eth Price: 1866.93
        // Total Supply: 384818030.963268482407003957
        // https://curve.fi/#/ethereum/pools/3pool/deposit

        mockRootPrice(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 535_370_000_000_000); //USDC
        mockRootPrice(0x6B175474E89094C44Da98b954EedeAC495271d0F, 534_820_000_000_000); //DAI
        mockRootPrice(0xdAC17F958D2ee523a2206206994597C13D831ec7, 535_540_000_000_000); //USDT

        oracle.registerPool(
            0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7, 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490, false
        );

        uint256 price = oracle.getPriceEth(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);

        assertApproxEqAbs(price, 549_453_000_000_000, 5e16);
    }

    function testUnregisterSecurity() public {
        oracle.registerPool(
            0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7, 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490, false
        );

        address testUser1 = vm.addr(34_343);
        vm.prank(testUser1);

        vm.expectRevert(abi.encodeWithSelector(IAccessController.AccessDenied.selector));
        oracle.unregister(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    }

    function testUnregisterMustExist() public {
        oracle.registerPool(
            0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7, 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490, false
        );

        address notRegisteredToken = vm.addr(33);
        vm.expectRevert(abi.encodeWithSelector(CurveV1StableEthOracle.NotRegistered.selector, notRegisteredToken));
        oracle.unregister(notRegisteredToken);
    }

    function testUnregister() public {
        oracle.registerPool(
            0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7, 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490, true
        );

        address[] memory tokens = oracle.getLpTokenToUnderlying(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
        (address pool, uint8 checkReentrancy) = oracle.lpTokenToPool(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);

        assertEq(tokens.length, 3);
        assertEq(tokens[0], 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        assertEq(tokens[1], 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        assertEq(tokens[2], 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        assertEq(pool, 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
        assertEq(checkReentrancy, 1);

        oracle.unregister(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);

        address[] memory afterTokens = oracle.getLpTokenToUnderlying(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
        (address afterPool, uint8 afterCheckReentrancy) =
            oracle.lpTokenToPool(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);

        assertEq(afterTokens.length, 0);
        assertEq(afterPool, address(0));
        assertEq(afterCheckReentrancy, 0);
    }

    function testRegistrationSecurity() public {
        address mockPool = vm.addr(25);
        address matchingLP = vm.addr(26);

        address testUser1 = vm.addr(34_343);
        vm.prank(testUser1);

        vm.expectRevert(abi.encodeWithSelector(IAccessController.AccessDenied.selector));
        oracle.registerPool(mockPool, matchingLP, true);
    }

    function testPoolRegistration() public {
        address mockResolver = vm.addr(24);
        address mockPool = vm.addr(25);
        address matchingLP = vm.addr(26);
        address nonMatchingLP = vm.addr(27);

        address[8] memory tokens;

        // Not stable swap
        vm.mockCall(
            mockResolver,
            abi.encodeWithSelector(CurveResolverMainnet.resolveWithLpToken.selector, mockPool),
            abi.encode(tokens, 0, matchingLP, false)
        );

        CurveV1StableEthOracle localOracle =
            new CurveV1StableEthOracle(systemRegistry, CurveResolverMainnet(mockResolver));

        vm.expectRevert(abi.encodeWithSelector(CurveV1StableEthOracle.NotStableSwap.selector, mockPool));
        localOracle.registerPool(mockPool, matchingLP, true);

        // stable swap but not matching
        vm.mockCall(
            mockResolver,
            abi.encodeWithSelector(CurveResolverMainnet.resolveWithLpToken.selector, mockPool),
            abi.encode(tokens, 0, nonMatchingLP, true)
        );

        vm.expectRevert(
            abi.encodeWithSelector(CurveV1StableEthOracle.ResolverMismatch.selector, matchingLP, nonMatchingLP)
        );
        localOracle.registerPool(mockPool, matchingLP, true);
    }

    function testNoTokensWillRevert() public {
        address mockResolver = vm.addr(24);
        address mockPool = vm.addr(25);
        address matchingLP = vm.addr(26);

        address[8] memory tokens;

        CurveV1StableEthOracle localOracle =
            new CurveV1StableEthOracle(systemRegistry, CurveResolverMainnet(mockResolver));

        // stable swap but not matching
        vm.mockCall(
            mockResolver,
            abi.encodeWithSelector(CurveResolverMainnet.resolveWithLpToken.selector, mockPool),
            abi.encode(tokens, 0, matchingLP, true)
        );

        localOracle.registerPool(mockPool, matchingLP, true);

        vm.expectRevert(abi.encodeWithSelector(CurveV1StableEthOracle.NotRegistered.selector, matchingLP));
        oracle.getPriceEth(matchingLP);
    }

    function testReentrancy() public {
        mockRootPrice(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 1e18); //ETH
        mockRootPrice(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84, 1e18); //stETH

        oracle.registerPool(STETH_ETH_POOL, STETH_ETH_LP_TOKEN, true);

        // Create the tester
        CurveEthStETHReentrancyTest tester = new CurveEthStETHReentrancyTest(oracle);

        // Make sure the tester has ETH and stETH so it can do an add_liquidity call
        deal(address(tester), 10e18);
        vm.prank(address(tester));
        STETH_CONTRACT.submit{ value: 1 ether }(address(0));

        tester.run();

        assertEq(tester.priceReceived(), type(uint256).max);
        assertEq(tester.getPriceFailed(), true);

        // Ensure running the same call outside of the reentrancy state works
        uint256 price = oracle.getPriceEth(STETH_ETH_LP_TOKEN);

        assertApproxEqAbs(price, 1 ether, 1e17);
    }

    function mockRootPrice(address token, uint256 price) internal {
        vm.mockCall(
            address(rootPriceOracle),
            abi.encodeWithSelector(IRootPriceOracle.getPriceEth.selector, token),
            abi.encode(price)
        );
    }

    function generateSystemRegistry(
        address registry,
        address accessControl,
        address rootOracle
    ) internal returns (ISystemRegistry) {
        vm.mockCall(registry, abi.encodeWithSelector(ISystemRegistry.rootPriceOracle.selector), abi.encode(rootOracle));

        vm.mockCall(
            registry, abi.encodeWithSelector(ISystemRegistry.accessController.selector), abi.encode(accessControl)
        );

        return ISystemRegistry(registry);
    }
}

contract CurveEthStETHReentrancyTest {
    address private constant STETH_ETH_POOL = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
    address private constant STETH_ETH_LP_TOKEN = ST_ETH_CURVE_LP_TOKEN_MAINNET;

    CurveV1StableEthOracle private oracle;
    uint256 public priceReceived = type(uint256).max;
    bool public getPriceFailed = false;

    constructor(CurveV1StableEthOracle _oracle) {
        oracle = _oracle;
    }

    function run() external {
        uint256[2] memory amounts;
        amounts[0] = 1 ether;
        amounts[1] = 1 ether;

        uint256[2] memory outAmounts;
        outAmounts[0] = 5e17;
        outAmounts[1] = 5e17;

        IERC20 lpToken = IERC20(STETH_ETH_LP_TOKEN);
        IERC20 stETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        stETH.approve(STETH_ETH_POOL, 1 ether);

        ICurveStableSwap pool = ICurveStableSwap(STETH_ETH_POOL);
        pool.add_liquidity{ value: 1 ether }(amounts, 0);

        uint256 bal = lpToken.balanceOf(address(this));
        pool.remove_liquidity(bal, outAmounts);
    }

    receive() external payable {
        if (msg.sender == STETH_ETH_POOL) {
            try oracle.getPriceEth(STETH_ETH_LP_TOKEN) returns (uint256 price) {
                priceReceived = price;
            } catch {
                getPriceFailed = true;
            }
        }
    }
}
