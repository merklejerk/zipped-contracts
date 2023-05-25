// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./ZExecution.sol";
import "./ZRuntimeConstants.sol";
import "./ZBase.sol";

/// @dev Fallback handlers for Self-extracting zipped contracts.
/// @author Zipped Contracts (https://github.com/merklejerk/zipped-contracts)
contract ZFallback is ZExecution {
    /// @dev The fallback handler for a self-extracting zcall contract.
    ///      The self-extracting zcall contract always delegatecalls this function when it receives
    ///      any call.
    ///      Although it takes no args, it expects the calldata from the self-extracting
    ///      contract's fallback to be appended to msg.data (our calldata).
    ///      selector: 0000009f
    function selfExtractingZCallFallback__fq1aqw47v() external {
       _handleSelfExtractingFallback(ZExecution.zcallWithRawResult.selector);
    }
    
    /// @dev The fallback handler for a self-extracting zrun contract.
    ///      The self-extracting zrun contract always delegatecalls this function when it receives
    ///      any call.
    ///      Although it takes no args, it expects the calldata from the self-extracting
    ///      contract's fallback to be appended to msg.data (our calldata).
    ///      selector: 0000000b
    function selfExtractingZRunFallback__wme3t() external {
        _handleSelfExtractingFallback(ZExecution.zrunWithRawResult.selector);
    }

    /// @notice Check if a caller to an unzipped contract is the zipped version of that contract.
    function isZippedCaller(address caller, address unzipped) external view returns (bool) {
        (, bytes32 unzippedHash) = _readMetadata(caller);
        return _computeZCallDeployAddress(caller, unzippedHash) == unzipped;
    }

    function _handleSelfExtractingFallback(bytes4 execSelector) private {
        uint256 ZIPPED_DATA_OFFSET = ZRuntimeConstants.ZIPPED_DATA_OFFSET;

        // The zipped contract handler will append its deployed address to the calldata.
        address zipped = abi.decode(msg.data[msg.data.length - 32:], (address));
        // The original calldata for zipped contract call is appended right
        // after ours.
        bytes calldata origCallData = msg.data[4:msg.data.length-32];
        uint256 zippedDataSize = zipped.code.length - ZIPPED_DATA_OFFSET;
        (uint24 unzippedSize, bytes32 unzippedHash) = _readMetadata(zipped);
        // Call the zip execute function.
        if (execSelector == ZExecution.zcallWithRawResult.selector) {
            zcallWithRawResult(
                zipped,
                ZIPPED_DATA_OFFSET,
                zippedDataSize,
                unzippedSize,
                unzippedHash,
                origCallData
            );
        } else { // ZExecution.zrunWithRawResult.selector
            zrunWithRawResult(
                zipped,
                ZIPPED_DATA_OFFSET,
                zippedDataSize,
                unzippedSize,
                unzippedHash,
                origCallData
            );
        }
    }

    function _readMetadata(address zipped)
        private view
        returns (uint24 unzippedSize, bytes32 unzippedHash)
    {
        uint256 FALLBACK_SIZE = ZRuntimeConstants.FALLBACK_SIZE;
        uint256 METADATA_SIZE = ZRuntimeConstants.METADATA_SIZE;
        // Read metadata from zipped contract's bytecode.
        assembly ("memory-safe") {
            let p := mload(0x40)
            // Metadata comes right after the fallback.
            extcodecopy(zipped, p, FALLBACK_SIZE, METADATA_SIZE)
            unzippedSize := shr(232, mload(p)) // 3 bytes
            unzippedHash := mload(add(p, 3)) // 32 bytes
        }
    }
}