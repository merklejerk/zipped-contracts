// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./ZExecution.sol";

/// @dev Constants for self-extracting contracts.
/// @author Zipped Contracts (https://github.com/merklejerk/zipped-contracts)
library ZRuntimeConstants {
    uint256 internal constant FALLBACK_SIZE = 0x4E;
    uint256 internal constant METADATA_SIZE = 35;
    uint256 internal constant ZIPPED_DATA_OFFSET = FALLBACK_SIZE + METADATA_SIZE;
}