// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/ZExecution.sol";
import "./LibContractStorage.sol";
import "./ZipUtil.sol";

contract ZExecutionTest is ZExecution, ZipUtil, Test {
    using LibContractStorage for bytes;
    using LibContractStorage for address;

    address zcallZipped;
    uint256 zcallUnzippedSize;
    bytes32 zcallUnzippedHash;
    address zrunZipped;
    uint256 zrunUnzippedSize;
    bytes32 zrunUnzippedHash;

    constructor() {
        {
            bytes memory creationCode = type(ZCallTestContract).creationCode;
            bytes memory zippedInitCode = _zip(creationCode);
            zcallUnzippedSize = creationCode.length;
            zcallUnzippedHash = keccak256(creationCode);
            zcallZipped = zippedInitCode.store();
        }
        {
            bytes memory creationCode = type(ZRunTestContract).creationCode;
            bytes memory zippedInitCode = _zip(creationCode);
            zrunUnzippedSize = creationCode.length;
            zrunUnzippedHash = keccak256(creationCode);
            zrunZipped = zippedInitCode.store();
        }
    }

    function test_zcall_result() external {
        bytes memory hashPayload = bytes("hello, world!");
        bytes32 h = abi.decode(this.zcall(
            zcallZipped,
            1,
            zcallZipped.code.length-1,
            zcallUnzippedSize,
            zcallUnzippedHash,
            abi.encodeCall(ZCallTestContract.hash, (hashPayload))
        ), (bytes32));
        assertEq(h, keccak256(hashPayload));
    }

    function test_zcall_failure() external {
        vm.expectRevert('woops');
        this.zcall(
            zcallZipped,
            1,
            zcallZipped.code.length-1,
            zcallUnzippedSize,
            zcallUnzippedHash,
            abi.encodeCall(ZCallTestContract.conditionalFailure, (1337))
        );
    }

    function test_zcall_badHash() external {
        vm.expectRevert(UnzippedHashMismatchError.selector);
        this.zcall(
            zcallZipped,
            1,
            zcallZipped.code.length-1,
            zcallUnzippedSize,
            ~zcallUnzippedHash,
            abi.encodeCall(ZCallTestContract.conditionalFailure, (1234))
        );
    }

    function test_zrun_result() external {
        bytes memory payload = bytes("hello, world!");
        bytes memory r = this.zrun(
            zrunZipped,
            1,
            zrunZipped.code.length-1,
            zrunUnzippedSize,
            zrunUnzippedHash,
            abi.encodeWithSelector(bytes4(0), 1234, payload)
        );
        assertEq(r, abi.encode(payload));
    }

    function test_zrun_failure() external {
        bytes memory payload = bytes("hello, world!");
        vm.expectRevert(CreationFailedError.selector);
        this.zrun(
            zrunZipped,
            1,
            zrunZipped.code.length-1,
            zrunUnzippedSize,
            zrunUnzippedHash,
            abi.encodeWithSelector(bytes4(0), 1337, payload)
        );
    }

    function test_zrun_badHash() external {
        bytes memory payload = bytes("hello, world!");
        vm.expectRevert(UnzippedHashMismatchError.selector);
        this.zrun(
            zrunZipped,
            1,
            zrunZipped.code.length-1,
            zrunUnzippedSize,
            ~zrunUnzippedHash,
            abi.encodeWithSelector(bytes4(0), 1234, payload)
        );
    }
}

contract ZCallTestContract {
    function hash(bytes memory data) external pure returns (bytes32) {
        return keccak256(data);
    }

    function conditionalFailure(uint256 x) external pure {
        require(x != 1337, 'woops');
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