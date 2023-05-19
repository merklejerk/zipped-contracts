// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./ZExecution.sol";

/// @dev Constants for self-extracting contracts.
/// @author merklejerk (https://github.com/merklejerk)
library ZRuntimeConstants {
    uint256 internal constant FALLBACK_SIZE = 0x3E;
    uint256 internal constant METADATA_SIZE = 11;
    uint256 internal constant ZIPPED_DATA_OFFSET = FALLBACK_SIZE + METADATA_SIZE;
}