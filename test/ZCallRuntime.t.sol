// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/ZCallExecution.sol";
import "../src/ZCallRuntime.sol";
import "./LibContractStorage.sol";
import "./ZipUtil.sol";

contract ZCallRuntimeTest is ZCallRuntime, ZCallExecution, ZipUtil, Test {
    using LibContractStorage for bytes;
    using LibContractStorage for address;

    bytes zcallZippedInitCode;
    uint256 zcallUnzippedSize;
    bytes zrunZippedInitCode;
    uint256 zrunUnzippedSize;

    constructor() {
        {
            bytes memory creationCode = type(ZCallTestContract).creationCode;
            zcallZippedInitCode = _zip(creationCode);
            zcallUnzippedSize = creationCode.length;
        }
        {
            bytes memory creationCode = type(ZRunTestContract).creationCode;
            zrunZippedInitCode = _zip(creationCode);
            zrunUnzippedSize = creationCode.length;
        }
    }

    function _deploy(bytes memory initCode) private returns (address a) {
        assembly { a := create(0, add(initCode, 0x20), mload(initCode)) }
        require(a != address(0), 'create failed');
    }

    function test_zcall_result() external {
        bytes memory hashPayload = bytes("hello, world!");
        ZCallTestContract zipped = ZCallTestContract(_deploy(
            this.createSelfExtractingZCallInitCode(zcallZippedInitCode, zcallUnzippedSize)
        ));
        bytes32 h = zipped.hash(hashPayload);
        assertEq(h, keccak256(hashPayload));
    }

    function test_zcall_failure() external {
        ZCallTestContract zipped = ZCallTestContract(_deploy(
            this.createSelfExtractingZCallInitCode(zcallZippedInitCode, zcallUnzippedSize)
        ));
        vm.expectRevert('woops');
        zipped.conditionalFailure(1337);
    }

    function test_zcall_doesNotAcceptEth() external {
        ZCallTestContract zipped = ZCallTestContract(_deploy(
            this.createSelfExtractingZCallInitCode(zcallZippedInitCode, zcallUnzippedSize)
        ));
        vm.expectRevert();
        zipped.conditionalFailure{value: 1}(1234);
    }

    function test_zrun_result() external {
        bytes memory payload = bytes("hello, world!");
        ZRunTestContract zipped = ZRunTestContract(_deploy(
            this.createSelfExtractingZRunInitCode(zrunZippedInitCode, zrunUnzippedSize)
        ));
        bytes memory r = zipped.run(1234, payload);
        assertEq(r, payload);
    }

    function test_zrun_failure() external {
        bytes memory payload = bytes("hello, world!");
        ZRunTestContract zipped = ZRunTestContract(_deploy(
            this.createSelfExtractingZRunInitCode(zrunZippedInitCode, zrunUnzippedSize)
        ));
        vm.expectRevert(CreationFailedError.selector);
        zipped.run(1337, payload);
    }

    function test_zrun_doesNotAcceptEth() external {
        bytes memory payload = bytes("hello, world!");
        ZRunTestContract zipped = ZRunTestContract(_deploy(
            this.createSelfExtractingZRunInitCode(zrunZippedInitCode, zrunUnzippedSize)
        ));
        vm.expectRevert();
        zipped.run{value: 1}(1234, payload);
    }
}

contract ZCallTestContract {
    function hash(bytes memory data) external payable returns (bytes32) {
        return keccak256(data);
    }

    function conditionalFailure(uint256 x) external payable {
        require(x != 1337, 'woops');
    }
}

contract ZRunTestContract {
    constructor(uint256 x, bytes memory data) payable {
        bytes memory result = abi.encode(run(x, data));
        assembly { return(add(result, 0x20), mload(result)) }
    }

    function run(uint256 x, bytes memory data) public payable returns (bytes memory) {
        require(x != 1337, 'woops');
        return data;
    }
}