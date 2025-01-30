// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SingleTimeUpgradableProxy.sol";

import {UniversalResolver as UniversalResolverV1} from "../src/mocks/UniversalResolverV1.sol";
import {UniversalResolver as UniversalResolverV2} from "../src/mocks/UniversalResolverV2.sol";

import {ENS} from "@ens-contracts-urv3/contracts/registry/ENS.sol";

contract ProxyTest is Test {
    address constant ADMIN = address(0x123);
    address constant USER = address(0x456);
    address constant STRANGER = address(0x789);

    SingleTimeUpgradableProxy proxy;
    UniversalResolverV1 urV1;
    UniversalResolverV2 urV2;

    ENS ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    function setUp() public {
        string[] memory urls = new string[](1);
        urls[0] = "http://universal-offchain-resolver.local";

        urV1 = new UniversalResolverV1();
        urV2 = new UniversalResolverV2();

        bytes memory initData = abi.encodeWithSelector(UniversalResolverV1.initialize.selector, ens, urls);
        vm.prank(ADMIN);
        proxy = new SingleTimeUpgradableProxy(ADMIN, address(urV1), initData);
    }

    /////// Core Functionality Tests ///////
    function test_InitialState() public view {
        assertEq(proxy.admin(), ADMIN);
        assertEq(proxy.implementation(), address(urV1));

        UniversalResolverV1 proxyV1 = UniversalResolverV1(address(proxy));
        console.log("proxyV1.owner()");
        console.logAddress(proxyV1.owner());
        assertEq(proxyV1.owner(), ADMIN);
    }

    function test_ProxyFunctionality() public {
        UniversalResolverV1 proxyV1 = UniversalResolverV1(address(proxy));

        string[] memory urls = new string[](1);
        urls[0] = "https://test1";
        vm.prank(proxyV1.owner());
        proxyV1.setGatewayURLs(urls);

        assertEq(proxyV1.batchGatewayURLs(0), urls[0]);
    }

    /////// Upgrade Tests ///////
    function test_SuccessfulUpgrade() public {
        string[] memory urls = new string[](1);
        urls[0] = "https://test1";
        bytes memory initData = abi.encodeWithSelector(UniversalResolverV1.initialize.selector, ens, urls);
        vm.prank(ADMIN);
        proxy.upgradeToAndCall(address(urV2), initData);

        assertEq(proxy.implementation(), address(urV2));
        assertEq(proxy.admin(), address(0));

        UniversalResolverV2 upgraded = UniversalResolverV2(address(proxy));

        urls[0] = "https://test2";

        console.log("urV2 - owner");
        console.logAddress(urV2.owner());
        console.log("urV2 - address");
        console.logAddress(address(urV2));
        console.log("implementation address");
        console.logAddress(proxy.implementation());
        console.log("upgraded - owner");
        console.logAddress(upgraded.owner());

        vm.prank(ADMIN);
        upgraded.setUrls(urls);
        assertEq(upgraded._urls(0), urls[0]);
    }

    function test_StoragePersistanceAfterUpgrade() public {
        string[] memory urls = new string[](1);
        urls[0] = "http://universal-offchain-resolver.local";

        bytes memory initDataV1 = abi.encodeWithSelector(UniversalResolverV1.initialize.selector, ens, urls);
        vm.prank(ADMIN);
        SingleTimeUpgradableProxy proxyTemp = new SingleTimeUpgradableProxy(ADMIN, address(urV1), initDataV1);

        UniversalResolverV1 proxyV1 = UniversalResolverV1(address(proxyTemp));
        UniversalResolverV2 proxyV2 = UniversalResolverV2(address(proxyTemp));

        urls[0] = "https://test1";
        vm.prank(ADMIN);
        proxyV1.setGatewayURLs(urls);

        bytes memory initData = abi.encodeWithSelector(UniversalResolverV1.initialize.selector, ens, urls);

        vm.prank(ADMIN);
        proxyTemp.upgradeToAndCall(address(urV2), initData);
        assertEq(proxyV2._urls(0), urls[0]);
    }
}
