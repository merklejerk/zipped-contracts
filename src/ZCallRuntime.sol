// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "./RuntimeDeployer.sol";
import "./ZCallExecution.sol";

/// @dev Runtime generation functions for ZCall.
/// @author merklejerk (https://github.com/merklejerk)
contract ZCallRuntime {
    error SafeCastError();

    uint256 constant FALLBACK_SIZE = 0x5B;

    function createSelfExtractingZCallInitCode(
        bytes calldata zippedInitCode,
        uint256 unzippedInitCodeSize
    )
        public
        view
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(RuntimeDeployer).creationCode,
            abi.encode(createSelfExtractingZCallRuntime(zippedInitCode, unzippedInitCodeSize))
        );
    }

    function createSelfExtractingZRunInitCode(
        bytes calldata zippedInitCode,
        uint256 unzippedInitCodeSize
    )
        public
        view
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            type(RuntimeDeployer).creationCode,
            abi.encode(createSelfExtractingZRunRuntime(zippedInitCode, unzippedInitCodeSize))
        );
    }

    function createSelfExtractingZCallRuntime(
        bytes calldata zippedInitCode,
        uint256 unzippedInitCodeSize
    )
        public
        view
        returns (bytes memory runtime)
    {
        /**********************************************************************
        Runtime for a self-extracting zcall contract will be:
            FALLBACK():
                CALLVALUE
                ISZERO
                PUSH1 0x06
                JUMPI
                INVALID
                JUMPDEST // :0x06
                // Build up calldata to zcall() ///////////////////////////////////
                PUSH4 0x00000000 // selector
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
                CALLDATACOPY
                // Call zcall() ///////////////////////////////////////////////////
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
                PUSH2 0x59
                JUMPI
                RETURN
                JUMPDEST // :0x59
                REVERT
            DATA:
                ...zippedInitCode
        **********************************************************************/
        runtime = abi.encodePacked(
            //// FALLBACK()
            hex"3415600657fe5b63",
            bytes4(ZCallExecution.zcallWithRawResult.selector),
            hex"345234595261",
            uint16(FALLBACK_SIZE),
            hex"595261",
            uint16(zippedInitCode.length),
            hex"595262",
            _safeCastToUint24(unzippedInitCodeSize),
            hex"595260a05952365952363459373434601c805903903473",
            address(this),
            hex"5af1343d3d34343e911561005957f35bfd",
            //// DATA
            zippedInitCode
        );
        assert(runtime.length == FALLBACK_SIZE + zippedInitCode.length);
    }

    function createSelfExtractingZRunRuntime(
        bytes calldata zippedInitCode,
        uint256 unzippedInitCodeSize
    )
        public
        view
        returns (bytes memory runtime)
    {
        // Runtime for a self-extracting zrun() contract is the same as a zcall() one
        // except the function selector being called is this.zrun.selector
        runtime = abi.encodePacked(
            //// FALLBACK()
            hex"3415600657fe5b63",
            bytes4(ZCallExecution.zrunWithRawResult.selector),
            hex"345234595261",
            uint16(FALLBACK_SIZE),
            hex"595261",
            uint16(zippedInitCode.length),
            hex"595262",
            _safeCastToUint24(unzippedInitCodeSize),
            hex"595260a05952365952363459373434601c805903903473",
            address(this),
            hex"5af1343d3d34343e911561005957f35bfd",
            //// DATA
            zippedInitCode
        );
        assert(runtime.length == FALLBACK_SIZE + zippedInitCode.length);
    }

    function _safeCastToUint24(uint256 x) private pure returns (uint24) {
        if (x > type(uint24).max) {
            revert SafeCastError();
        }
        return uint24(x);
    }
}