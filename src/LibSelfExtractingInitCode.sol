// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "./ZRuntime.sol";

/// @notice Utility for generating deployable initcode for self-extracting contracts.
/// @dev Not meant to be deployed.
/// @author merklejerk (https://github.com/merklejerk)
library LibSelfExtractingInitCode {
    /// @notice Create deployable initcode for a self-extracting zcall contract.
    /// @param z ZRuntime instance.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function createSelfExtractingZCallInitCode(
        ZRuntime z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes8 unzippedInitCodeHash
    )
        internal
        view
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(RuntimeDeployer).creationCode,
            abi.encode(z.createSelfExtractingZCallRuntime(
                zippedInitCode,
                unzippedInitCodeSize,
                unzippedInitCodeHash
            ))
        );
    }

    /// @notice Create deployable initcode for a self-extracting zrun contract.
    /// @param z ZRuntime instance.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function createSelfExtractingZRunInitCode(
        ZRuntime z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes8 unzippedInitCodeHash
    )
        internal
        view
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(RuntimeDeployer).creationCode,
            abi.encode(z.createSelfExtractingZRunRuntime(
                zippedInitCode,
                unzippedInitCodeSize,
                unzippedInitCodeHash
            ))
        );
    }
}

/// @notice Deploys the data passed into its constructor.
/// @author merklejerk (https://github.com/merklejerk)
contract RuntimeDeployer {
    constructor(bytes memory runtimeCode) {
        assembly("memory-safe") { return(add(runtimeCode, 0x20), mload(runtimeCode)) }
    }
}

