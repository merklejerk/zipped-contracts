// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "./Inflate2.sol";
import "./RuntimeDeployer.sol";

/// @notice Zipped Contracts (v1.00.0)
/// @author merklejerk (https://github.com/merklejerk)
contract ZCall is Inflate2 {
    error OnlySelfError();
    error CreationFailedError();
    error __Fail();
    error __Success();
    
    uint256 constant FALLBACK_SIZE = 0x53;

    function deploySelfExtractingContract(
        bytes calldata zippedInitCode,
        uint24 unzippedInitCodeSize
    )
        public
        returns (address deployed)
    {
        bytes memory initCode = abi.encodePacked(
            type(RuntimeDeployer).creationCode,
            abi.encode(createSelfExtractingRuntime(zippedInitCode, unzippedInitCodeSize))
        );
        assembly("memory-safe") {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
        if (deployed == address(0)) {
            revert CreationFailedError();
        }
    }

    function createSelfExtractingInitCode(
        bytes calldata zippedInitCode,
        uint24 unzippedInitCodeSize
    )
        public
        view
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(RuntimeDeployer).creationCode,
            abi.encode(createSelfExtractingRuntime(zippedInitCode, unzippedInitCodeSize))
        );
    }

    function createSelfExtractingRuntime(
        bytes calldata zippedInitCode,
        uint24 unzippedInitCodeSize
    )
        public
        view
        returns (bytes memory runtime)
    {
        /**********************************************************************
        Runtime for a self-extracting contract will be:
            FALLBACK():
                // Build up calldata to zcall() ///////////////////////////////////
                // selector
                PUSH4 0xb26e8f4a
                CALLVALUE
                MSTORE
                // zipped (0 is alias for msg.sender)
                CALLVALUE
                MSIZE
                MSTORE
                // dataOffset (ZIPPED_INITCODE.codeoffset)
                PUSH2 0xFFFF
                MSIZE
                MSTORE
                // dataSize (zippedInitCode.length)
                PUSH2 0xFFFF
                MSIZE
                MSTORE
                // unzippedInitCodeSize
                PUSH3 0xFFFFFF
                MSIZE
                MSTORE
                // callData.offset
                PUSH1 0xA0
                MSIZE
                MSTORE
                // callData.length
                CALLDATASIZE
                MSIZE
                MSTORE
                // callData
                CALLDATASIZE
                CALLVALUE
                MSIZE
                CODECOPY
                // Call zcall() ///////////////////////////////////////////////////
                CALLVALUE
                CALLVALUE
                PUSH1 28
                MSIZE
                DUP2
                SUB
                CALLVALUE
                PUSH20 0x0000000000000000000000000000000000000000 // zcall address
                GAS
                CALL
                // Handle result //////////////////////////////////////////////////
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
                PUSH2 0x51
                JUMPI
                RETURN
                JUMPDEST // :0x51
                REVERT
            DATA:
                ...zippedInitCode
        **********************************************************************/
        runtime = abi.encodePacked(
            //// FALLBACK()
            hex"63b26e8f4a345234595261",
            uint16(FALLBACK_SIZE),
            hex"595261",
            uint16(zippedInitCode.length),
            hex"595262",
            uint24(unzippedInitCodeSize),
            hex"595260a05952365952363459393434601c5981033473",
            address(this),
            hex"5af1343d3d34343e911561005157f35bfd",
            //// DATA
            zippedInitCode
        );
        assert(runtime.length == FALLBACK_SIZE + zippedInitCode.length);
    }

    function zcall(
        address zipped,
        uint256 dataOffset,
        uint256 dataSize,
        uint256 unzippedSize,
        bytes memory callData
    )
        external
        returns (bytes memory /* result */)
    {
        zipped = zipped == address(0) ? msg.sender : zipped;
        //  Unzip to initcode.
        bytes memory initCode = this.inflateFrom(zipped, dataOffset, dataSize, unzippedSize);
        // Deploy and call without (permanently) altering state.
        try this.__deployUnzippedCallAndRevert(initCode, callData) {}
        catch (bytes memory r) {
            if (r.length >= 4) {
                bytes4 selector;
                assembly("memory-safe") { selector := mload(add(r, 0x20)) }
                if (selector == __Fail.selector) {
                    assembly("memory-safe") {
                        revert(add(r, 0x24), sub(mload(r), 0x04))
                    }
                } else if (selector == __Success.selector) {
                    assembly("memory-safe") {
                        return(add(r, 0x24), sub(mload(r), 0x04))
                    }
                }
            }
            assembly("memory-safe") {
                revert(add(r, 0x20), mload(r))
            }
        }
        assert(false);
    }

    function __deployUnzippedCallAndRevert(
        bytes memory initCode,
        bytes memory callData
    )
        external
    {
        if (msg.sender != address(this)) {
            revert OnlySelfError();
        }
        address unzipped;
        assembly {
            unzipped := create(0, add(initCode, 0x20), mload(initCode))
        }
        if (unzipped == address(0)) {
            revert CreationFailedError();
        }
        (bool b, bytes memory r) = unzipped.call(callData);
        uint256 len = r.length;
        bytes4 selector = b ? __Success.selector : __Fail.selector;
        assembly {
            if iszero(b) {
                mstore(r, shr(224, selector))
                revert(sub(r, 0x04), add(len, 4))
            }
        }
    }
}