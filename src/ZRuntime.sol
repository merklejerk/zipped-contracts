// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "./ZExecution.sol";

/// @dev Self-extracting functions for zipped contracts.
/// @author merklejerk (https://github.com/merklejerk)
contract ZRuntime {
    error SafeCastError();

    uint256 constant FALLBACK_SIZE = 0x3E;
    uint256 constant METADATA_SIZE = 11;
    uint256 constant ZIPPED_DATA_OFFSET = FALLBACK_SIZE + METADATA_SIZE;

    /// @notice Create runtime for a self-extracting zcall contract.
    /// @param zippedInitCode The zipped init code of the original contract.
    /// @param unzippedInitCodeSize The size of the unzipped init code of the original contract.
    /// @param unzippedInitCodeHash The hash of the unzipped init code of the original contract.
    function createSelfExtractingZCallRuntime(
        bytes calldata zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes8 unzippedInitCodeHash
    )
        public
        view
        returns (bytes memory runtime)
    {
        return _createSelfExtractingRuntime(
            this.selfExtractingZCallFallback__fq1aqw47v.selector,
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
        bytes calldata zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes8 unzippedInitCodeHash
    )
        public
        view
        returns (bytes memory runtime)
    {
        return _createSelfExtractingRuntime(
            this.selfExtractingZRunFallback__wme3t.selector,
            zippedInitCode,
            unzippedInitCodeSize,
            unzippedInitCodeHash
        );
    }

    /// @dev The fallback handler for a self-extracting zcall contract.
    ///      The self-extracting zcall contract always calls this function when it receives
    ///      any call.
    ///      Although it takes no args, it expects the calldata from the self-extracting
    ///      contract's fallback to be appended to msg.data (our calldata).
    ///      selector: 0000009f
    function selfExtractingZCallFallback__fq1aqw47v() external {
       _handleSelfExtractingFallback(ZExecution.zcallWithRawResult.selector);
    }
    
    /// @dev The fallback handler for a self-extracting zrun contract.
    ///      The self-extracting zrun contract always calls this function when it receives
    ///      any call.
    ///      Although it takes no args, it expects the calldata from the self-extracting
    ///      contract's fallback to be appended to msg.data (our calldata).
    ///      selector: 0000000b
    function selfExtractingZRunFallback__wme3t() external {
        _handleSelfExtractingFallback(ZExecution.zrunWithRawResult.selector);
    }

    function _handleSelfExtractingFallback(bytes4 execSelector) private {
        uint256 zippedDataSize = msg.sender.code.length - ZIPPED_DATA_OFFSET;
        uint24 unzippedSize;
        bytes8 unzippedHash;
        // Read metadata from runtime code.
        assembly("memory-safe") {
            let p := mload(0x40)
            // Metadata comes right after the fallback.
            extcodecopy(caller(), p, FALLBACK_SIZE, METADATA_SIZE)
            unzippedSize := shr(232, mload(p)) // 3 bytes
            unzippedHash := shl(192, shr(192, mload(add(p, 3)))) // 8 bytes
        }
        // Call the zip execute function.
        (bool b, bytes memory r) = address(this).call(abi.encodeWithSelector(execSelector,
            msg.sender,
            ZIPPED_DATA_OFFSET,
            zippedDataSize,
            unzippedSize,
            unzippedHash,
            // The original calldata for self-extracting contract is appended right
            // after ours.
            msg.data[4:]
        ));
        // Bubble up result.
        if (!b) {
            assembly { revert(add(r, 0x20), mload(r)) }
        }
        assembly { return(add(r, 0x20), mload(r)) }
    }

    function _createSelfExtractingRuntime(
        bytes4 fallbackSelector,
        bytes calldata zippedInitCode,
        uint256 unzippedInitCodeSize,
        bytes8 unzippedInitCodeHash
    )
        private
        view
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
            address(this),
            hex"5af1343d3d34343e911561003c57f35bfd",
            //// METADATA
            _safeCastToUint24(unzippedInitCodeSize),
            bytes8(unzippedInitCodeHash),
            //// ZIPPED DATA
            zippedInitCode
        );
        assert(runtime.length == ZIPPED_DATA_OFFSET + zippedInitCode.length);
    }
    
    function _safeCastToUint24(uint256 x) private pure returns (uint24) {
        if (x > type(uint24).max) {
            revert SafeCastError();
        }
        return uint24(x);
    }
}