// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./Inflate2.sol";

/// @dev Execution functions for zipped contracts.
/// @author merklejerk (https://github.com/merklejerk)
contract ZExecution is Inflate2 {
    error OnlySelfError();
    error CreationFailedError();
    error UnzippedHashMismatchError();
    error __Fail();
    error __Success();
    
    /// @notice Make an arbitrary function call on a zipped contract.
    /// @dev The contract will be unzipped, deployed, then called.
    ///      All changes will be revert()ed to prevent permanently modifying state.
    /// @param zipped The address that holds the zipped initcode data in its bytecode.
    /// @param dataOffset The offset into `zipped`'s bytecode to start reading zipped data.
    /// @param dataSize The size of the zipped data.
    /// @param unzippedSize The size of the unzipped initcode.
    /// @param unzippedHash The hash of the unzipped initcode.
    /// @param callData ABI-encoded function call to make against the unzipped (and deployed) contract.
    /// @return result The result of the call as a bytes array.
    function zcall(
        address zipped,
        uint256 dataOffset,
        uint256 dataSize,
        uint256 unzippedSize,
        bytes8 unzippedHash,
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
            unzippedHash,
            callData
        )));
        if (!s) {
            assembly { revert(add(result, 0x20), mload(result)) }
        }
    }

    /// @notice Make an arbitrary function call on a zipped contract.
    /// @dev The contract will be unzipped, deployed, then called.
    ///      All changes will be revert()ed to prevent permanently modifying state.
    ///      Performs a raw return of the result, as if the function was called directly.
    /// @param zipped The address that holds the zipped initcode data in its bytecode.
    /// @param dataOffset The offset into `zipped`'s bytecode to start reading zipped data.
    /// @param dataSize The size of the zipped data.
    /// @param unzippedSize The size of the unzipped initcode.
    /// @param unzippedHash The hash of the unzipped initcode.
    /// @param callData ABI-encoded function call to make against the unzipped (and deployed) contract.
    function zcallWithRawResult(
        address zipped,
        uint256 dataOffset,
        uint256 dataSize,
        uint256 unzippedSize,
        bytes8 unzippedHash,
        bytes calldata callData
    )
        external
        // Naked result of the call is returned.
    {
        zipped = zipped == address(0) ? msg.sender : zipped;
        //  Unzip to initcode.
        bytes memory initCode = this.inflateFrom(zipped, dataOffset, dataSize, unzippedSize);
        if (unzippedHash != bytes8(0)) {
            if (bytes8(keccak256(initCode)) != unzippedHash) {
                revert UnzippedHashMismatchError();
            }
        }
        // Deploy and call without (permanently) altering state.
        try this.__execZCall(initCode, callData) {}
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

    function __execZCall(
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

    /// @notice Execute the initcode of a zipped contract.
    /// @dev The contract will be unzipped and deployed. The unzipped initcode should write (return())
    ///      its successful result data to its runtime bytecode.
    ///      All changes will be revert()ed to prevent permanently modifying state.
    /// @param zipped The address that holds the zipped initcode data in its bytecode.
    /// @param dataOffset The offset into `zipped`'s bytecode to start reading zipped data.
    /// @param dataSize The size of the zipped data.
    /// @param unzippedSize The size of the unzipped initcode.
    /// @param unzippedHash The hash of the unzipped initcode.
    /// @param initArgs ABI-encoded call data to pass to unzipped initcode during deployment.
    ///                 Function selector should be included but will be stripped.
    /// @return result The result (runtime bytecode) of the unzipped initcode as a bytes array.
    function zrun(
        address zipped,
        uint256 dataOffset,
        uint256 dataSize,
        uint256 unzippedSize,
        bytes8 unzippedHash,
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
            unzippedHash,
            initArgs
        )));
        if (!s) {
            assembly { revert(add(result, 0x20), mload(result)) }
        }
    }

    /// @notice Execute the initcode of a zipped contract.
    /// @dev The contract will be unzipped and deployed. The unzipped initcode should write (return())
    ///      its successful result data to its runtime bytecode.
    ///      All changes will be revert()ed to prevent permanently modifying state.
    ///      Performs a raw return of the result, as if the function was called directly.
    /// @param zipped The address that holds the zipped initcode data in its bytecode.
    /// @param dataOffset The offset into `zipped`'s bytecode to start reading zipped data.
    /// @param dataSize The size of the zipped data.
    /// @param unzippedSize The size of the unzipped initcode.
    /// @param unzippedHash The hash of the unzipped initcode.
    /// @param initArgs ABI-encoded call data to pass to unzipped initcode during deployment.
    ///                 Function selector should be included but will be stripped.
    function zrunWithRawResult(
        address zipped,
        uint256 dataOffset,
        uint256 dataSize,
        uint256 unzippedSize,
        bytes8 unzippedHash,
        bytes calldata initArgs
    )
        external
        // Naked runtime code is returned.
    {
        zipped = zipped == address(0) ? msg.sender : zipped;
        //  Unzip to initcode.
        bytes memory initCode = this.inflateFrom(zipped, dataOffset, dataSize, unzippedSize);
        if (unzippedHash != bytes8(0)) {
            if (bytes8(keccak256(initCode)) != unzippedHash) {
                revert UnzippedHashMismatchError();
            }
        }
        // Deploy without (permanently) altering state.
        try this.__execZRun(initCode, initArgs) {}
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

    function __execZRun(
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