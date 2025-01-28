// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SingleTimeUpgradableProxy} from "../src/SingleTimeUpgradableProxy.sol";
import {MockUniversalV1} from "../src/mocks/MockUniversalV1.sol";

contract SingleTimeUpgradableProxyScript is Script {
    address constant ADMIN = address(0x123);

    SingleTimeUpgradableProxy public sup;
    MockUniversalV1 public universalV1;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        universalV1 = new MockUniversalV1();
        sup = new SingleTimeUpgradableProxy(address(universalV1), ADMIN, "");

        vm.stopBroadcast();
    }
}
