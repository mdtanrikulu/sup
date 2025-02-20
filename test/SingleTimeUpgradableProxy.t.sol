// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SingleTimeUpgradableProxy.sol";
import "../src/mocks/MockUniversalV1.sol";
import "../src/mocks/MockUniversalV2.sol";

contract ProxyTest is Test {
    address constant ADMIN = address(0x123);
    address constant USER = address(0x456);
    address constant STRANGER = address(0x789);

    SingleTimeUpgradableProxy proxy;
    MockUniversalV1 v1;
    MockUniversalV2 v2;
    MockUniversalV2 v2Bad;

    function setUp() public {
        v1 = new MockUniversalV1();
        v2 = new MockUniversalV2();
        v2Bad = new MockUniversalV2();

        bytes memory initData = abi.encodeCall(MockUniversalV1.initialize, ());
        proxy = new SingleTimeUpgradableProxy(address(v1), ADMIN, initData);
    }

    /////// Core Functionality Tests ///////
    function test_InitialState() public view {
        assertEq(proxy.admin(), ADMIN);
        assertEq(proxy.implementation(), address(v1));

        MockUniversalV1 proxyV1 = MockUniversalV1(address(proxy));
        assertEq(proxyV1.owner(), address(this));
    }

    function test_ProxyFunctionality() public {
        MockUniversalV1 proxyV1 = MockUniversalV1(address(proxy));

        vm.prank(ADMIN);
        proxyV1.setValue(100);
        assertEq(proxyV1.value(), 100);
    }

    /////// Upgrade Tests ///////
    function test_SuccessfulUpgrade() public {
        vm.prank(ADMIN);
        proxy.upgradeToAndCall(address(v2), "");

        assertEq(proxy.implementation(), address(v2));
        assertEq(proxy.admin(), address(0));

        MockUniversalV2 upgraded = MockUniversalV2(address(proxy));
        vm.prank(USER);
        upgraded.setSecondValue(200);
        assertEq(upgraded.secondValue(), 200);
    }

    function test_StoragePersistanceAfterUpgrade() public {
        bytes memory initData = abi.encodeCall(MockUniversalV1.initialize, ());
        SingleTimeUpgradableProxy proxyTemp = new SingleTimeUpgradableProxy(address(v1), ADMIN, initData);

        MockUniversalV1 proxyV1 = MockUniversalV1(address(proxyTemp));
        MockUniversalV2 proxyV2 = MockUniversalV2(address(proxyTemp));

        vm.prank(USER);
        proxyV1.setValue(100);

        vm.prank(ADMIN);
        proxyTemp.upgradeToAndCall(address(v2), "");
        assertEq(proxyV2.value(), 100);
    }

    /////// Security Tests ///////
    function test_RevertIf_NonAdminUpgrade() public {
        vm.prank(STRANGER);
        vm.expectRevert(SingleTimeUpgradableProxy.CallerNotAdmin.selector);
        proxy.upgradeToAndCall(address(v2), "");
    }

    function test_RevertIf_DoubleUpgrade() public {
        vm.startPrank(ADMIN);
        proxy.upgradeToAndCall(address(v2), "");

        vm.expectRevert(SingleTimeUpgradableProxy.CallerNotAdmin.selector);
        proxy.upgradeToAndCall(address(v2Bad), "");
    }

    function test_RevertIf_SameImplementation() public {
        vm.prank(ADMIN);
        vm.expectRevert(SingleTimeUpgradableProxy.SameImplementation.selector);
        proxy.upgradeToAndCall(address(v1), "");
    }

    function test_RevertIf_NonContractUpgrade() public {
        vm.prank(ADMIN);
        vm.expectRevert(SingleTimeUpgradableProxy.InvalidImplementation.selector);
        proxy.upgradeToAndCall(STRANGER, "");
    }

    /////// Edge Cases ///////
    function test_AdminRevocationAfterUpgrade() public {
        vm.prank(ADMIN);
        proxy.upgradeToAndCall(address(v2), "");

        bytes32 adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        address currentAdmin = address(uint160(uint256(vm.load(address(proxy), adminSlot))));
        assertEq(currentAdmin, address(0));
    }

    function test_CannotInitializeImplementation() public {
        vm.expectRevert(bytes4(keccak256("InvalidInitialization()")));
        MockUniversalV1(address(v1)).initialize();
    }
}
