// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./ZExecution.sol";
import "./ZRuntimeConstants.sol";
import "./ZBase.sol";

/// @dev Fallback handlers for Self-extracting zipped contracts.
/// @author merklejerk (https://github.com/merklejerk)
contract ZFallback is ZBase {

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

    function _handleSelfExtractingFallback(bytes4 execSelector) private {
        uint256 FALLBACK_SIZE = ZRuntimeConstants.FALLBACK_SIZE;
        uint256 ZIPPED_DATA_OFFSET = ZRuntimeConstants.ZIPPED_DATA_OFFSET;
        uint256 METADATA_SIZE = ZRuntimeConstants.METADATA_SIZE;

        uint256 zippedDataSize = address(this).code.length - ZIPPED_DATA_OFFSET;
        uint24 unzippedSize;
        bytes32 unzippedHash;
        // Read metadata from runtime code.
        assembly("memory-safe") {
            let p := mload(0x40)
            // Metadata comes right after the fallback.
            extcodecopy(address(), p, FALLBACK_SIZE, METADATA_SIZE)
            unzippedSize := shr(232, mload(p)) // 3 bytes
            unzippedHash := mload(add(p, 3)) // 32 bytes
        }
        // Call the zip execute function.
        (bool b, bytes memory r) = _IMPL.delegatecall(abi.encodeWithSelector(execSelector,
            ZIPPED_DATA_OFFSET,
            zippedDataSize,
            unzippedSize,
            unzippedHash,
            // The original calldata for zipped contract call is appended right
            // after ours.
            msg.data[4:]
        ));
        // Bubble up result.
        if (!b) {
            assembly { revert(add(r, 0x20), mload(r)) }
        }
        assembly { return(add(r, 0x20), mload(r)) }
    }
}