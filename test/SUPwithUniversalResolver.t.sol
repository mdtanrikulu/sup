// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SingleTimeUpgradableProxy.sol";

import {UniversalResolver as UniversalResolverV1} from "@ens-contracts-main/contracts/utils/UniversalResolver.sol";
import {UniversalResolver as UniversalResolverV2} from
    "@ens-contracts-urv3/contracts/universalResolver/UniversalResolver.sol";
import {ENS} from "@ens-contracts-urv3/contracts/registry/ENS.sol";

import {Create2} from "@openzeppelin/contracts-sup/utils/Create2.sol";

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

        urV1 = UniversalResolverV1(0xce01f8eee7E479C928F8919abD53E553a36CeF67);
        vm.prank(ADMIN);
        urV2 = new UniversalResolverV2(ens, urls);

        // // Deploy through proxy to preserve msg.sender as ADMIN
        // vm.startBroadcast(ADMIN);
        // bytes memory constructorArgs = abi.encode(ens, urls);
        // bytes memory bytecode = abi.encodePacked(
        //     type(UniversalResolverV2).creationCode,
        //     constructorArgs
        // );
        // bytes32 salt = bytes32(0);
        // urV2 = UniversalResolverV2(Create2.deploy(0, salt, bytecode));
        // vm.stopBroadcast();

        proxy = new SingleTimeUpgradableProxy(address(urV1), ADMIN, "");
    }

    /////// Core Functionality Tests ///////
    function test_InitialState() public view {
        assertEq(proxy.admin(), ADMIN);
        assertEq(proxy.implementation(), address(urV1));

        UniversalResolverV1 proxyV1 = UniversalResolverV1(address(proxy));
        assertEq(proxyV1.owner(), address(0));
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
        vm.prank(ADMIN);
        proxy.upgradeToAndCall(address(urV2), "");

        assertEq(proxy.implementation(), address(urV2));
        assertEq(proxy.admin(), address(0));

        UniversalResolverV2 upgraded = UniversalResolverV2(address(proxy));

        string[] memory urls = new string[](1);
        urls[0] = "https://test1";

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
        SingleTimeUpgradableProxy proxyTemp = new SingleTimeUpgradableProxy(address(urV1), ADMIN, "");

        UniversalResolverV1 proxyV1 = UniversalResolverV1(address(proxyTemp));
        UniversalResolverV2 proxyV2 = UniversalResolverV2(address(proxyTemp));

        string[] memory urls = new string[](1);
        urls[0] = "https://test1";
        vm.prank(proxyV1.owner());
        proxyV1.setGatewayURLs(urls);

        vm.prank(ADMIN);
        proxyTemp.upgradeToAndCall(address(urV2), "");
        assertEq(proxyV2._urls(0), urls[0]);
    }
}
