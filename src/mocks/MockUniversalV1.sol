// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-sup/proxy/utils/Initializable.sol";

contract MockUniversalV1 {
    uint256 public value;
    address public owner;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        owner = msg.sender;
    }

    function setValue(uint256 _value) external {
        value = _value;
    }
}
