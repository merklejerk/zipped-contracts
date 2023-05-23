// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/ZExecution.sol";
import "script/ZipUtil.sol";
import "./LibContractStorage.sol";

contract ZExecutionTest is ZExecution, ZipUtil, Test {
    using LibContractStorage for bytes;
    using LibContractStorage for address;

    ZCallTestContract zcallZipped;
    uint256 zcallUnzippedSize;
    bytes32 zcallUnzippedHash;
    ZRunTestContract zrunZipped;
    uint256 zrunUnzippedSize;
    bytes32 zrunUnzippedHash;

    constructor() {
        {
            bytes memory creationCode = type(ZCallTestContract).creationCode;
            bytes memory zippedInitCode = _zip(creationCode);
            zcallUnzippedSize = creationCode.length;
            zcallUnzippedHash = keccak256(creationCode);
            zcallZipped = ZCallTestContract(address(new ZippedContainer(
                ZExecution(address(this)),
                ZExecution.zcallWithRawResult.selector,
                zippedInitCode,
                zcallUnzippedSize,
                zcallUnzippedHash
            )));
        }
        {
            bytes memory creationCode = type(ZRunTestContract).creationCode;
            bytes memory zippedInitCode = _zip(creationCode);
            zrunUnzippedSize = creationCode.length;
            zrunUnzippedHash = keccak256(creationCode);
            zrunZipped = ZRunTestContract(address(new ZippedContainer(
                ZExecution(address(this)),
                ZExecution.zrunWithRawResult.selector,
                zippedInitCode,
                zrunUnzippedSize,
                zrunUnzippedHash
            )));
        }
    }

    function test_zcall_result() external {
        bytes memory hashPayload = bytes("hello, world!");
        bytes32 h = zcallZipped.hash(hashPayload);
        assertEq(h, keccak256(hashPayload));
    }

    function test_zcall_failure() external {
        vm.expectRevert('woops');
        zcallZipped.conditionalFailure(1337);
    }

    function test_zcall_badHash() external {
        ZippedFallback(address(zcallZipped)).__setHash(~zcallUnzippedHash);
        vm.expectRevert(UnzippedHashMismatchError.selector);
        zcallZipped.conditionalFailure(1234);
    }

    function test_zcall_staticContext() external {
        vm.expectRevert(StaticContextError.selector);
        IStaticTestContracts(address(zcallZipped)).conditionalFailure(1234);
    }

    function test_zcall_reenter() external {
        assertEq(zcallZipped.reenter(2), 2);
    }

    function test_zcall_reenterIndirect() external {
        assertEq(zcallZipped.reenterIndirect(2), 2);
    }

    function test_zcall_twice() external {
        bytes memory hashPayload1 = bytes("hello, world!");
        bytes memory hashPayload2 = bytes("goodbye, world!");
        bytes32 h1 = zcallZipped.hash(hashPayload1);
        assertEq(h1, keccak256(hashPayload1));
        bytes32 h2 = zcallZipped.hash(hashPayload2);
        assertEq(h2, keccak256(hashPayload2));
    }

    function test_zrun_result() external {
        bytes memory payload = bytes("hello, world!");
        bytes memory r = zrunZipped.run(1234, payload);
        assertEq(r, payload);
    }

    function test_zrun_failure() external {
        bytes memory payload = bytes("hello, world!");
        vm.expectRevert(CreationFailedError.selector);
        zrunZipped.run(1337, payload);
    }

    function test_zrun_badHash() external {
        bytes memory payload = bytes("hello, world!");
        ZippedFallback(address(zrunZipped)).__setHash(~zrunUnzippedHash);
        vm.expectRevert(UnzippedHashMismatchError.selector);
        zrunZipped.run(1234, payload);
    }

    function test_zrun_staticContext() external {
        bytes memory payload = bytes("hello, world!");
        vm.expectRevert(StaticContextError.selector);
        IStaticTestContracts(address(zrunZipped)).run(1234, payload);
    }
}

contract ZippedStorage {
    uint256[1024] internal __padding;
    ZExecution internal _z;
    bytes4 internal _runSelector;
    uint256 internal _dataOffset;
    uint256 internal _unzippedSize;
    bytes32 internal _unzippedHash;
}

contract ZippedFallback is ZippedStorage {
    function __setHash(bytes32 h) external {
        _unzippedHash = h;
    }

    fallback(bytes calldata callData) external returns (bytes memory r) {
        bool b;
        (b, r) = address(_z).delegatecall(abi.encodeWithSelector(
            _runSelector,
            _dataOffset,
            address(this).code.length - _dataOffset,
            _unzippedSize,
            _unzippedHash,
            callData
        ));
        if (!b) {
            assembly { revert(add(r, 0x20), mload(r)) }
        }
    }
}

contract ZippedContainer is ZippedStorage {
    constructor(
        ZExecution z,
        bytes4 runSelector,
        bytes memory initCode,
        uint256 unzippedSize,
        bytes32 unzippedHash
    ) {
        _z = z;
        _runSelector = runSelector;
        _dataOffset = type(ZippedFallback).runtimeCode.length;
        _unzippedSize = unzippedSize;
        _unzippedHash = unzippedHash;
        bytes memory runtime = abi.encodePacked(
            type(ZippedFallback).runtimeCode,
            initCode
        );
       assembly { return(add(runtime, 0x20), mload(runtime)) } 
    }
}

interface IStaticTestContracts {
    function hash(bytes memory data) external view returns (bytes32);
    function conditionalFailure(uint256 x) external view;
    function run(uint256 x, bytes memory data) external view returns (bytes memory);
}

contract ZCallTestContract {
    function hash(bytes memory data) external returns (bytes32) {
        return keccak256(data);
    }

    function conditionalFailure(uint256 x) external {
        require(x != 1337, 'woops');
    }

    function reenter(uint256 n) external returns (uint256 r) {
        if (n > 0) {
            return this.reenter(n - 1) + 1;
        }
        return 0;
    }

    function reenterIndirect(uint256 n) external returns (uint256 r) {
        if (n > 0) {
            return ZCallTestContract(msg.sender).reenterIndirect(n - 1) + 1;
        }
        return 0;
    }
}

contract ZRunTestContract {
    constructor(uint256 x, bytes memory data) {
        bytes memory result = abi.encode(run(x, data));
        assembly { return(add(result, 0x20), mload(result)) }
    }

    function run(uint256 x, bytes memory data) public returns (bytes memory) {
        require(x != 1337, 'woops');
        return data;
    }
}