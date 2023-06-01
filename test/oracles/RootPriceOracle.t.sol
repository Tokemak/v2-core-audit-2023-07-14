// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

//import { console } from "forge-std/console.sol";
import { IwstEth } from "src/interfaces/external/lido/IwstEth.sol";
import { Test, StdCheats, StdUtils } from "forge-std/Test.sol";
import { SystemRegistry } from "src/SystemRegistry.sol";
import { AccessController } from "src/security/AccessController.sol";
import { WstETHEthOracle } from "src/oracles/providers/WstETHEthOracle.sol";
import { RootPriceOracle } from "src/oracles/RootPriceOracle.sol";
import { IPriceOracle } from "src/interfaces/oracles/IPriceOracle.sol";
import { IERC20Metadata } from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Errors } from "src/utils/Errors.sol";
import { ISystemBound } from "src/interfaces/ISystemBound.sol";
import { IAccessController } from "src/interfaces/security/IAccessController.sol";

contract RootPriceOracleTests is Test {
    SystemRegistry private _systemRegistry;
    AccessController private _accessController;
    RootPriceOracle private _rootPriceOracle;

    function setUp() public {
        _systemRegistry = new SystemRegistry();
        _accessController = new AccessController(address(_systemRegistry));
        _systemRegistry.setAccessController(address(_accessController));
        _rootPriceOracle = new RootPriceOracle(_systemRegistry);
    }

    function testConstruction() public {
        vm.expectRevert();
        new RootPriceOracle(SystemRegistry(address(0)));

        assertEq(address(_rootPriceOracle.getSystemRegistry()), address(_systemRegistry));
    }

    function testRegisterMappingParamValidation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "token"));
        _rootPriceOracle.registerMapping(address(0), IPriceOracle(address(0)));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "oracle"));
        _rootPriceOracle.registerMapping(vm.addr(23), IPriceOracle(address(0)));

        address badRegistry = vm.addr(888);
        address badOracle = vm.addr(999);
        mockSystemBound(badOracle, badRegistry);
        vm.expectRevert(abi.encodeWithSelector(Errors.SystemMismatch.selector, address(_rootPriceOracle), badOracle));
        _rootPriceOracle.registerMapping(vm.addr(23), IPriceOracle(badOracle));
    }

    function testReplacingAttemptOnRegister() public {
        address oracle = vm.addr(999);
        mockSystemBound(oracle, address(_systemRegistry));
        _rootPriceOracle.registerMapping(vm.addr(23), IPriceOracle(oracle));

        address newOracle = vm.addr(9996);
        mockSystemBound(newOracle, address(_systemRegistry));
        vm.expectRevert(abi.encodeWithSelector(RootPriceOracle.AlreadyRegistered.selector, vm.addr(23)));
        _rootPriceOracle.registerMapping(vm.addr(23), IPriceOracle(newOracle));
    }

    function testSuccessfulRegister() public {
        address token = vm.addr(5);
        address oracle = vm.addr(999);
        mockSystemBound(oracle, address(_systemRegistry));
        _rootPriceOracle.registerMapping(token, IPriceOracle(oracle));

        assertEq(address(_rootPriceOracle.tokenMappings(token)), oracle);
    }

    function testReplacingParamValidation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "token"));
        _rootPriceOracle.replaceMapping(address(0), IPriceOracle(address(0)), IPriceOracle(address(0)));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "oldOracle"));
        _rootPriceOracle.replaceMapping(vm.addr(23), IPriceOracle(address(0)), IPriceOracle(address(0)));

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "newOracle"));
        _rootPriceOracle.replaceMapping(vm.addr(23), IPriceOracle(vm.addr(23)), IPriceOracle(address(0)));

        address oracle = vm.addr(999);
        mockSystemBound(oracle, address(vm.addr(333)));
        vm.expectRevert(abi.encodeWithSelector(Errors.SystemMismatch.selector, address(_rootPriceOracle), oracle));
        _rootPriceOracle.replaceMapping(vm.addr(23), IPriceOracle(vm.addr(23)), IPriceOracle(oracle));
    }

    function testReplaceMustMatchOld() public {
        address token = vm.addr(5);
        address oracle = vm.addr(999);
        mockSystemBound(oracle, address(_systemRegistry));
        _rootPriceOracle.registerMapping(token, IPriceOracle(oracle));

        address newOracle = vm.addr(9998);
        mockSystemBound(newOracle, address(_systemRegistry));
        address badOld = vm.addr(5454);
        vm.expectRevert(abi.encodeWithSelector(RootPriceOracle.ReplaceOldMismatch.selector, token, badOld, oracle));
        _rootPriceOracle.replaceMapping(token, IPriceOracle(badOld), IPriceOracle(newOracle));
    }

    function testReplaceMustBeNew() public {
        address token = vm.addr(5);
        address oracle = vm.addr(999);
        mockSystemBound(oracle, address(_systemRegistry));
        _rootPriceOracle.registerMapping(token, IPriceOracle(oracle));

        vm.expectRevert(abi.encodeWithSelector(RootPriceOracle.ReplaceAlreadyMatches.selector, token, oracle));
        _rootPriceOracle.replaceMapping(token, IPriceOracle(oracle), IPriceOracle(oracle));
    }

    function testReplaceIsSet() public {
        address token = vm.addr(5);
        address oracle = vm.addr(999);
        mockSystemBound(oracle, address(_systemRegistry));
        _rootPriceOracle.registerMapping(token, IPriceOracle(oracle));

        address newOracle = vm.addr(9998);
        mockSystemBound(newOracle, address(_systemRegistry));
        _rootPriceOracle.replaceMapping(token, IPriceOracle(oracle), IPriceOracle(newOracle));

        assertEq(address(_rootPriceOracle.tokenMappings(token)), newOracle);
    }

    function testRemoveParamValidation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "token"));
        _rootPriceOracle.replaceMapping(address(0), IPriceOracle(address(0)), IPriceOracle(address(0)));
    }

    function testRemoveChecksIsSet() public {
        address token = vm.addr(5);

        vm.expectRevert(abi.encodeWithSelector(RootPriceOracle.MappingDoesNotExist.selector, token));
        _rootPriceOracle.removeMapping(token);
    }

    function testRemoveDeletes() public {
        address token = vm.addr(5);
        address oracle = vm.addr(999);
        mockSystemBound(oracle, address(_systemRegistry));
        _rootPriceOracle.registerMapping(token, IPriceOracle(oracle));

        _rootPriceOracle.removeMapping(token);

        assertEq(address(_rootPriceOracle.tokenMappings(token)), address(0));
    }

    function testRegisterMappingSecurity() public {
        address testUser1 = vm.addr(34_343);
        vm.prank(testUser1);

        vm.expectRevert(abi.encodeWithSelector(IAccessController.AccessDenied.selector));
        _rootPriceOracle.registerMapping(vm.addr(23), IPriceOracle(vm.addr(4444)));
    }

    function testReplacerMappingSecurity() public {
        address testUser1 = vm.addr(34_343);
        vm.prank(testUser1);

        vm.expectRevert(abi.encodeWithSelector(IAccessController.AccessDenied.selector));

        _rootPriceOracle.replaceMapping(vm.addr(23), IPriceOracle(vm.addr(4444)), IPriceOracle(vm.addr(4444)));
    }

    function testRemoveMappingSecurity() public {
        address testUser1 = vm.addr(34_343);
        vm.prank(testUser1);

        vm.expectRevert(abi.encodeWithSelector(IAccessController.AccessDenied.selector));
        _rootPriceOracle.removeMapping(vm.addr(23));
    }

    function testRegisterAndResolve() public {
        address oracle = vm.addr(44_444);
        address token = vm.addr(55);
        mockOracle(oracle, token, 5e18);
        mockSystemBound(oracle, address(_systemRegistry));
        _rootPriceOracle.registerMapping(token, IPriceOracle(oracle));

        uint256 price = _rootPriceOracle.getPriceEth(token);

        assertEq(price, 5e18);
    }

    function testResolveBailsIfNotRegistered() public {
        address oracle = vm.addr(44_444);
        address token = vm.addr(55);
        mockOracle(oracle, token, 5e18);
        mockSystemBound(oracle, address(_systemRegistry));
        _rootPriceOracle.registerMapping(token, IPriceOracle(oracle));

        vm.expectRevert(abi.encodeWithSelector(RootPriceOracle.MissingTokenOracle.selector, vm.addr(44)));
        _rootPriceOracle.getPriceEth(vm.addr(44));
    }

    function mockOracle(address oracle, address token, uint256 price) internal {
        vm.mockCall(
            address(oracle), abi.encodeWithSelector(IPriceOracle.getPriceEth.selector, token), abi.encode(price)
        );
    }

    function mockSystemBound(address component, address system) internal {
        vm.mockCall(component, abi.encodeWithSelector(ISystemBound.getSystemRegistry.selector), abi.encode(system));
    }
}
