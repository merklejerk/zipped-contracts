// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./ZExecution.sol";
import "./ZRuntimeConstants.sol";

/// @author Zipped Contracts (https://github.com/merklejerk/zipped-contracts)
contract ZBase {
    address immutable internal _IMPL;

    constructor() {
        _IMPL = address(this);
    }
}