// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @notice Deploys the data passed into its constructor.
/// @author merklejerk (https://github.com/merklejerk)
contract RuntimeDeployer {
    constructor(bytes memory runtimeCode) {
        assembly("memory-safe") { return(add(runtimeCode, 0x20), mload(runtimeCode)) }
    }
}
