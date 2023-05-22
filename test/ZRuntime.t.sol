// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/Z.sol";
import "src/LibZRuntime.sol";
import "script/ZipUtil.sol";
import "./LibContractStorage.sol";

contract ZRuntimeTest is Z, ZipUtil, Test {
    using LibContractStorage for bytes;
    using LibContractStorage for address;
    using LibZRuntime for ZRuntimeTest;

    bytes zcallZippedInitCode;
    uint256 zcallUnzippedSize;
    bytes32 zcallUnzippedHash;
    bytes zrunZippedInitCode;
    uint256 zrunUnzippedSize;
    bytes32 zrunUnzippedHash;

    constructor() {
        {
            bytes memory creationCode = type(ZCallTestContract).creationCode;
            zcallZippedInitCode = _zip(creationCode);
            zcallUnzippedSize = creationCode.length;
            zcallUnzippedHash = keccak256(creationCode);
        }
        {
            bytes memory creationCode = type(ZRunTestContract).creationCode;
            zrunZippedInitCode = _zip(creationCode);
            zrunUnzippedSize = creationCode.length;
            zrunUnzippedHash = keccak256(creationCode);
        }
    }

    function test_zcall_result() external {
        bytes memory hashPayload = bytes("hello, world!");
        ZCallTestContract zipped = ZCallTestContract(
            this.deploySelfExtractingZCallInitCode(zcallZippedInitCode, zcallUnzippedSize, zcallUnzippedHash)
        );
        bytes32 h = zipped.hash(hashPayload);
        assertEq(h, keccak256(hashPayload));
    }

    function test_zcall_reenter() external {
        ZCallTestContract zipped = ZCallTestContract(
            this.deploySelfExtractingZCallInitCode(zcallZippedInitCode, zcallUnzippedSize, zcallUnzippedHash)
        );
        assertEq(zipped.reenter(2), 2);
    }

    // TODO: This should not work.
    function test_zcall_storage() external {
        ZCallTestContract zipped = ZCallTestContract(
            this.deploySelfExtractingZCallInitCode(zcallZippedInitCode, zcallUnzippedSize, zcallUnzippedHash)
        );
        assertEq(zipped.getX(), 1);
        zipped.setX(2);
        assertEq(zipped.getX(), 2);
    }

    function test_zcall_failure() external {
        ZCallTestContract zipped = ZCallTestContract(
            this.deploySelfExtractingZCallInitCode(zcallZippedInitCode, zcallUnzippedSize, zcallUnzippedHash)
        );
        vm.expectRevert('woops');
        zipped.conditionalFailure(1337);
    }

    function test_zcall_doesNotAcceptEth() external {
        ZCallTestContract zipped = ZCallTestContract(
            this.deploySelfExtractingZCallInitCode(zcallZippedInitCode, zcallUnzippedSize, zcallUnzippedHash)
        );
        vm.expectRevert();
        zipped.conditionalFailure{value: 1}(1234);
    }

    function test_zrun_result() external {
        bytes memory payload = bytes("hello, world!");
        ZRunTestContract zipped = ZRunTestContract(
            this.deploySelfExtractingZRunInitCode(zrunZippedInitCode, zrunUnzippedSize, zrunUnzippedHash)
        );
        bytes memory r = zipped.run(1234, payload);
        assertEq(r, payload);
    }

    function test_zrun_failure() external {
        bytes memory payload = bytes("hello, world!");
        ZRunTestContract zipped = ZRunTestContract(
            this.deploySelfExtractingZRunInitCode(zrunZippedInitCode, zrunUnzippedSize, zrunUnzippedHash)
        );
        vm.expectRevert(CreationFailedError.selector);
        zipped.run(1337, payload);
    }

    function test_zrun_doesNotAcceptEth() external {
        bytes memory payload = bytes("hello, world!");
        ZRunTestContract zipped = ZRunTestContract(
            this.deploySelfExtractingZRunInitCode(zrunZippedInitCode, zrunUnzippedSize, zrunUnzippedHash)
        );
        vm.expectRevert();
        zipped.run{value: 1}(1234, payload);
    }
}

contract ZCallTestContract {
    uint256 _x = 1;

    function getX() external returns (uint256) {
        return _x;
    }

    function setX(uint256 x_) external {
        _x = x_;
    }

    function hash(bytes memory data) external payable returns (bytes32) {
        return keccak256(data);
    }

    function conditionalFailure(uint256 x) external payable {
        require(x != 1337, 'woops');
    }

    function reenter(uint256 n) external returns (uint256 r) {
        if (n > 0) {
            return this.reenter(n - 1) + 1;
        }
        return 0;
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