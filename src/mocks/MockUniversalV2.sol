// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockUniversalV1.sol";

contract MockUniversalV2 is MockUniversalV1 {
    uint256 public secondValue;

    function setSecondValue(uint256 _value) external {
        secondValue = _value;
    }
}
