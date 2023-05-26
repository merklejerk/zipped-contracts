// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "./Inflate2.sol";
import "./ZBase.sol";

/// @dev Execution functions for zipped contracts.
/// @author Zipped Contracts (https://github.com/merklejerk/zipped-contracts)
contract ZExecution is Inflate2, ZBase {
    error OnlyDelegateCallError();
    error CreationFailedError();
    error UnzippedHashMismatchError();
    error StaticContextError();
    error ZFail();
    error ZSuccess();

    // Revert if we are not in a delegatecall (from anyone but ourselves) context.
    modifier onlyDelegateCall() {
        if (address(this) == _IMPL) {
            revert OnlyDelegateCallError();
        }
        _;
    }

    // Revert if the current execution context is inside a staticcall().
    modifier noStaticContext() {
        {
            bool isStaticcall;
            bytes4 selector = this.__checkStaticContext.selector;
            address impl = _IMPL;
            assembly {
                mstore(0x00, selector)
                pop(call(1200, impl, 0, 0x00, 0x04, 0x00, 0x00))
                isStaticcall := iszero(eq(returndatasize(), 1))
            }
            if (isStaticcall) {
                revert StaticContextError();
            }
        }
        _;
    }

    /// @notice Make an arbitrary function call on a zipped contract.
    /// @dev The contract will be unzipped, deployed, then called.
    ///      All changes will be revert()ed to prevent permanently modifying state.
    ///      Performs a raw return of the result, as if the function was called directly.
    ///      Must be called via a delegatecall from the context of the zipped contract.
    /// @param zipped The address holding the zipped data. If different from address(this)
    ///               then a delegatecall() instead of a call() will be performed on
    ///               the unzipped contract.
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
        bytes32 unzippedHash,
        bytes calldata callData
    )
        public
        onlyDelegateCall
        // Naked result of the call is returned.
    {
        bytes memory initCode;
        address unzipped = _computeZCallDeployAddress(address(this), unzippedHash);
        bool shouldDelegateCall = address(this) != zipped;
        // Allow the original msg.sender to be recovered by the unzipped contract by
        // appending it to the calldata.
        bytes memory callDataWithSender = abi.encodePacked(callData, uint256(uint160(msg.sender)));
        if (unzipped.code.length == 0) {
            //  Unzip initcode.
            initCode = _inflateAndCheck(
                zipped,
                dataOffset,
                dataSize,
                unzippedSize,
                unzippedHash
            );
            // Deploy and call without (permanently) altering state.
            (bool b, bytes memory r) = _IMPL.delegatecall(abi.encodeCall(
                this.__execZCall,
                (unzipped, shouldDelegateCall, initCode, callDataWithSender)
            ));
            assert(!b);
            _handleExecRevert(r); // Terminates.
        } else {
            // The contract was already unzipped and deployed earlier in the call stack.
            // We can just call it directly and let the top level zcall do the clean up.
            (bool b, bytes memory r) = shouldDelegateCall
                ? unzipped.delegatecall(callDataWithSender)
                : unzipped.call(callDataWithSender);
            if (!b) {
                assembly { revert(add(r, 0x20), mload(r)) }
            }
            assembly { return(add(r, 0x20), mload(r)) }
        }
    }

    function __execZCall(
        address unzipped,
        bool shouldDelegateCall,
        bytes memory initCode,
        bytes memory callData
    )
        external
        noStaticContext
    {
        if (unzipped.code.length == 0) {
            assembly {
                unzipped := create2(
                    0,
                    add(initCode, 0x20),
                    mload(initCode),
                    address()
                )
            }
            if (unzipped == address(0)) {
                revert CreationFailedError();
            }
        }
        (bool b, bytes memory r) = shouldDelegateCall
            ? unzipped.delegatecall(callData)
            : unzipped.call(callData);
        uint256 len = r.length;
        bytes4 selector = b ? ZSuccess.selector : ZFail.selector;
        assembly {
            mstore(r, shr(224, selector))
            revert(add(r, 28), add(len, 4))
        }
    }

    /// @notice Execute the initcode of a zipped contract.
    /// @dev The contract will be unzipped and deployed. The unzipped initcode should write (return())
    ///      its successful result data to its runtime bytecode.
    ///      All changes will be revert()ed to prevent permanently modifying state.
    ///      Performs a raw return of the result, as if the function was called directly.
    ///      Must be called via a delegatecall from the context of the zipped contract.
    /// @param zipped The address holding the zipped data.
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
        bytes32 unzippedHash,
        bytes calldata initArgs
    )
        public
        onlyDelegateCall
        // Naked runtime code is returned.
    {
        //  Unzip initcode.
        bytes memory initCode = _inflateAndCheck(
            zipped,
            dataOffset,
            dataSize,
            unzippedSize,
            unzippedHash
        );
        // Allow the original msg.sender to be recovered by the unzipped contract by
        // appending it to the initArgs.
        bytes memory initArgsWithSender = abi.encodePacked(initArgs, uint256(uint160(msg.sender)));
        // Deploy without (permanently) altering state.
        (bool b, bytes memory r) = _IMPL.delegatecall(abi.encodeCall(
            this.__execZRun,
            (initCode, initArgsWithSender)
        ));
        assert(!b);
        _handleExecRevert(r); // Terminates.
    }

    function __execZRun(
        bytes memory initCode,
        bytes calldata initArgs
    )
        external
        noStaticContext
    {
        address unzipped;
        {
            bytes memory initCodeWithArgs = abi.encodePacked(initCode, initArgs[4:]);
            assembly {
                unzipped := create2(
                    0,
                    add(initCodeWithArgs, 0x20),
                    mload(initCodeWithArgs),
                    address()
                )
            }
        }
        if (unzipped == address(0)) {
            revert CreationFailedError();
        }
        bytes memory runtime = unzipped.code;
        uint256 len = runtime.length;
        bytes4 selector = ZSuccess.selector;
        assembly {
            mstore(runtime, shr(224, selector))
            revert(add(runtime, 28), add(len, 4))
        }
    }

    function __checkStaticContext() external {
        assembly {
            log0(0x00, 0x00)
            revert(0x00, 0x01)
        }
    }

    function _inflateAndCheck(
        address zipped,
        uint256 dataOffset,
        uint256 dataSize,
        uint256 unzippedSize,
        bytes32 unzippedHash
    )
        private view
        returns (bytes memory unzipped)
    {
        unzipped = Inflate2(_IMPL).inflateFrom(
            zipped,
            dataOffset,
            dataSize,
            unzippedSize
        );
        if (unzippedHash != bytes32(0)) {
            if (bytes32(keccak256(unzipped)) != unzippedHash) {
                revert UnzippedHashMismatchError();
            }
        }
    }

    function _handleExecRevert(bytes memory r) private pure {
        if (r.length >= 4) {
            bytes4 selector;
            assembly ("memory-safe") { selector := mload(add(r, 0x20)) }
            if (selector == ZFail.selector) {
                assembly("memory-safe") {
                    revert(add(r, 0x24), sub(mload(r), 0x04))
                }
            } else if (selector == ZSuccess.selector) {
                assembly("memory-safe") {
                    return(add(r, 0x24), sub(mload(r), 0x04))
                }
            }
        }
        assembly ("memory-safe") {
            revert(add(r, 0x20), mload(r))
        }
    }

    function _computeZCallDeployAddress(address zipped, bytes32 initCodeHash)
        internal pure
        returns (address d)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            zipped,
            uint256(uint160(zipped)),
            initCodeHash
        )))));
    }
}