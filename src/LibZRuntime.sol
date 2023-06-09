// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./Z.sol";

/// @notice Utility for generating deployable initcode for self-extracting contracts.
/// @dev Not meant to be deployed.
/// @author Zipped Contracts (https://github.com/merklejerk/zipped-contracts)
library LibZRuntime {
    error SafeCastError();

    /// @notice Deploy a self-extracting zcall contract.
    /// @param z Z instance.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function deploySelfExtractingZCallInitCode(
        Z z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes32 unzippedInitCodeHash
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
    /// @param z Z instance.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function deploySelfExtractingZRunInitCode(
        Z z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes32 unzippedInitCodeHash
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
    /// @param z Z instance.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function createSelfExtractingZCallInitCode(
        Z z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes32 unzippedInitCodeHash
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
    /// @param z Z instance.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function createSelfExtractingZRunInitCode(
        Z z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes32 unzippedInitCodeHash
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
        Z z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes32 unzippedInitCodeHash
    )
        internal
        pure
        returns (bytes memory runtime)
    {
        return _createSelfExtractingRuntime(
            z,
            ZFallback.selfExtractingZCallFallback__fq1aqw47v.selector,
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
        Z z,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes32 unzippedInitCodeHash
    )
        internal
        pure
        returns (bytes memory runtime)
    {
        return _createSelfExtractingRuntime(
            z,
            ZFallback.selfExtractingZRunFallback__wme3t.selector,
            zippedInitCode,
            unzippedInitCodeSize,
            unzippedInitCodeHash
        );
    }

    function _createSelfExtractingRuntime(
        Z z,
        bytes4 fallbackSelector,
        bytes memory zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes32 unzippedInitCodeHash
    )
        private
        pure
        returns (bytes memory runtime)
    {
        /**********************************************************************
            Runtime for a self-extracting contract will be:
                FALLBACK():
                    // Build calldata
                    RETURNDATASIZE
                    PUSH1 0x00 // fallback selector (both fallbacks have 1-significant-byte selectors)
                    RETURNDATASIZE
                    MSTORE
                    CALLDATASIZE
                    RETURNDATASIZE
                    MSIZE
                    CALLDATACOPY
                    PUSH20 0x0000000000000000000000000000000000000000 // deployed address
                    MSIZE
                    MSTORE
                    // Make call
                    RETURNDATASIZE
                    RETURNDATASIZE
                    PUSH1 28
                    DUP1
                    MSIZE
                    SUB
                    SWAP1
                    PUSH20 0x0000000000000000000000000000000000000000 // zcall address
                    GAS
                    DELEGATECALL
                    DUP2
                    RETURNDATASIZE
                    // Copy return data
                    RETURNDATASIZE
                    DUP3
                    DUP1
                    RETURNDATACOPY
                    // Return or revert
                    SWAP2
                    ISZERO
                    PUSH2 0x4c
                    JUMPI
                    RETURN
                    JUMPDEST // :0x4c
                    REVERT
                METADATA:
                    uint24(unzippedInitCodeSize)
                    bytes32(unzippedInitCodeHash)
                DATA:
                    bytes(zippedInitCode)
        **********************************************************************/
        
        runtime = abi.encodePacked(
            //// FALLBACK()
            hex"3d60",
            uint8(uint32(fallbackSelector)),
            hex"3d52363d593773",
            address(0), // To be filled in by RuntimeDeployer constructor
            hex"59523d3d601c8059039073",
            address(z),
            hex"5af4813d3d82803e911561004c57f35bfd",
            //// METADATA
            _safeCastToUint24(unzippedInitCodeSize),
            bytes32(unzippedInitCodeHash),
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

/// @notice Deploys a zipped contract.
/// @author Zipped Contracts (https://github.com/merklejerk/zipped-contracts)
contract RuntimeDeployer {
    constructor(bytes memory runtimeCode) {
        assembly ("memory-safe") {
            // Overwrite deployed address.
            {
                let p := add(runtimeCode, 0x2A)
                mstore(p, or(and(mload(p), 0xffffffffffffffffffffffff), shl(96, address())))
            }
            return(add(runtimeCode, 0x20), mload(runtimeCode))
        }
    }
}

