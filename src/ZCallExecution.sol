// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "./Inflate2.sol";

/// @dev Execution functions for ZCall.
/// @author merklejerk (https://github.com/merklejerk)
contract ZCallExecution is Inflate2 {
    error OnlySelfError();
    error CreationFailedError();
    error __Fail();
    error __Success();
    
    function zcall(
        address zipped,
        uint256 dataOffset,
        uint256 dataSize,
        uint256 unzippedSize,
        bytes calldata callData
    )
        external
        returns (bytes memory result)
    {
        bool s;
        (s, result) = address(this).call(abi.encodeCall(this.zcallWithRawResult, (
            zipped,
            dataOffset,
            dataSize,
            unzippedSize,
            callData
        )));
        if (!s) {
            assembly { revert(add(result, 0x20), mload(result)) }
        }
    }

    function zcallWithRawResult(
        address zipped,
        uint256 dataOffset,
        uint256 dataSize,
        uint256 unzippedSize,
        bytes calldata callData
    )
        external
        // Naked result of the call is returned.
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

    event Foo();

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
            mstore(r, shr(224, selector))
            revert(add(r, 28), add(len, 4))
        }
    }

    function zrun(
        address zipped,
        uint256 dataOffset,
        uint256 dataSize,
        uint256 unzippedSize,
        bytes calldata initArgs
    )
        external
        returns (bytes memory result)
    {
        bool s;
        (s, result) = address(this).call(abi.encodeCall(this.zrunWithRawResult, (
            zipped,
            dataOffset,
            dataSize,
            unzippedSize,
            initArgs
        )));
        if (!s) {
            assembly { revert(add(result, 0x20), mload(result)) }
        }
    }

    function zrunWithRawResult(
        address zipped,
        uint256 dataOffset,
        uint256 dataSize,
        uint256 unzippedSize,
        bytes calldata initArgs
    )
        external
        // Naked runtime code is returned.
    {
        zipped = zipped == address(0) ? msg.sender : zipped;
        //  Unzip to initcode.
        bytes memory initCode = this.inflateFrom(zipped, dataOffset, dataSize, unzippedSize);
        // Deploy without (permanently) altering state.
        try this.__deployUnzippedAndRevert(initCode, initArgs) {}
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

    event Poop(bytes x);

    function __deployUnzippedAndRevert(
        bytes memory initCode,
        bytes calldata initArgs
    )
        external
    {
        if (msg.sender != address(this)) {
            revert OnlySelfError();
        }
        address unzipped;
        {
            bytes memory initCodeWithArgs = abi.encodePacked(initCode, initArgs[4:]);
            emit Poop(initCodeWithArgs);
            assembly {
                unzipped := create(0, add(initCodeWithArgs, 0x20), mload(initCodeWithArgs))
            }
        }
        if (unzipped == address(0)) {
            revert CreationFailedError();
        }
        bytes memory runtime = unzipped.code;
        uint256 len = runtime.length;
        bytes4 selector = __Success.selector;
        assembly {
            mstore(runtime, shr(224, selector))
            revert(add(runtime, 28), add(len, 4))
        }
    }

}