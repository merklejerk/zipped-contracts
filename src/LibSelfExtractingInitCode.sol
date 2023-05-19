// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./ZRuntime.sol";

/// @notice Utility for generating deployable initcode for self-extracting contracts.
/// @dev Not meant to be deployed.
/// @author merklejerk (https://github.com/merklejerk)
library LibSelfExtractingInitCode {
    error SafeCastError();

    /// @notice Deploy a self-extracting zcall contract.
    /// @param z ZRuntime instance.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function deploySelfExtractingZCallInitCode(
        ZRuntime z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes8 unzippedInitCodeHash
    )
        internal
        returns (address deployed)
    {
        bytes memory initCode = createSelfExtractingZCallInitCode(
            z,
            zippedInitCode,
            unzippedInitCodeSize,
            unzippedInitCodeHash
        );
        assembly {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(deployed != address(0), 'deployment failed');
    }

    /// @notice Deploy a self-extracting zrun contract.
    /// @param z ZRuntime instance.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function deploySelfExtractingZRunInitCode(
        ZRuntime z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes8 unzippedInitCodeHash
    )
        internal
        returns (address deployed)
    {
        bytes memory initCode = createSelfExtractingZRunInitCode(
            z,
            zippedInitCode,
            unzippedInitCodeSize,
            unzippedInitCodeHash
        );
        assembly {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(deployed != address(0), 'deployment failed');
    }

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
        pure
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(RuntimeDeployer).creationCode,
            abi.encode(createSelfExtractingZCallRuntime(
                z,
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
        pure
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(RuntimeDeployer).creationCode,
            abi.encode(createSelfExtractingZRunRuntime(
                z,
                zippedInitCode,
                unzippedInitCodeSize,
                unzippedInitCodeHash
            ))
        );
    }

    /// @notice Create runtime for a self-extracting zcall contract.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function createSelfExtractingZCallRuntime(
        ZRuntime z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes8 unzippedInitCodeHash
    )
        internal
        pure
        returns (bytes memory runtime)
    {
        return _createSelfExtractingRuntime(
            z,
            ZRuntime.selfExtractingZCallFallback__fq1aqw47v.selector,
            zippedInitCode,
            unzippedInitCodeSize,
            unzippedInitCodeHash
        );
    }

    /// @notice Create runtime for a self-extracting zrun contract.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function createSelfExtractingZRunRuntime(
        ZRuntime z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes8 unzippedInitCodeHash
    )
        internal
        pure
        returns (bytes memory runtime)
    {
        return _createSelfExtractingRuntime(
            z,
            ZRuntime.selfExtractingZRunFallback__wme3t.selector,
            zippedInitCode,
            unzippedInitCodeSize,
            unzippedInitCodeHash
        );
    }

    function _createSelfExtractingRuntime(
        ZRuntime z,
        bytes4 fallbackSelector,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes8 unzippedInitCodeHash
    )
        private
        pure
        returns (bytes memory runtime)
    {
        /**********************************************************************
            Runtime for a self-extracting contract will be:
                FALLBACK():
                    CALLVALUE
                    ISZERO
                    PUSH1 0x06
                    JUMPI
                    INVALID
                    JUMPDEST // :0x06
                    PUSH1 0x00 // fallback selector (both fallbacks have 1-significant-byte selectors)
                    CALLVALUE
                    MSTORE
                    CALLDATASIZE
                    CALLVALUE
                    MSIZE
                    CALLDATACOPY
                    CALLVALUE
                    CALLVALUE
                    PUSH1 28
                    DUP1
                    MSIZE
                    SUB
                    SWAP1
                    CALLVALUE
                    PUSH20 0x0000000000000000000000000000000000000000 // zcall address
                    GAS
                    CALL
                    CALLVALUE
                    RETURNDATASIZE
                    // Copy return data
                    RETURNDATASIZE
                    CALLVALUE
                    CALLVALUE
                    RETURNDATACOPY
                    // Return or revert
                    SWAP2
                    ISZERO
                    PUSH2 0x3C
                    JUMPI
                    RETURN
                    JUMPDEST // :0x3C
                    REVERT
                METADATA:
                    uint24(unzippedInitCodeSize)
                    bytes8(unzippedInitCodeHash)
                DATA:
                    bytes(zippedInitCode)
        **********************************************************************/
        runtime = abi.encodePacked(
            //// FALLBACK()
            hex"3415600657fe5b60",
            uint8(uint32(fallbackSelector)),
            hex"3452363459373434601c805903903473",
            address(z),
            hex"5af1343d3d34343e911561003c57f35bfd",
            //// METADATA
            _safeCastToUint24(unzippedInitCodeSize),
            bytes8(unzippedInitCodeHash),
            //// ZIPPED DATA
            zippedInitCode
        );
        assert(runtime.length == ZRuntimeConstants.ZIPPED_DATA_OFFSET + zippedInitCode.length);
    }
    
    function _safeCastToUint24(uint256 x) private pure returns (uint24) {
        if (x > type(uint24).max) {
            revert SafeCastError();
        }
        return uint24(x);
    }
}

/// @notice Deploys the data passed into its constructor.
/// @author merklejerk (https://github.com/merklejerk)
contract RuntimeDeployer {
    constructor(bytes memory runtimeCode) {
        assembly("memory-safe") { return(add(runtimeCode, 0x20), mload(runtimeCode)) }
    }
}

