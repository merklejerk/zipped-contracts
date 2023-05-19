// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/LibSelfExtractingInitCode.sol";
import "./ZipUtil.sol";
import "./LibAddresses.sol";

contract DeployBase is Script, ZipUtil {
    function _zcallDeploy(bytes memory unzippedInitCode) internal returns (address deployed) {
        deployed = LibSelfExtractingInitCode.deploySelfExtractingZCallInitCode(
            ZRuntime(LibAddresses.getZ()),
            _zip(unzippedInitCode),
            unzippedInitCode.length,
            bytes8(keccak256(unzippedInitCode))
        );
        summarize(deployed, unzippedInitCode.length);
    }
    
    function _zrunDeploy(bytes memory unzippedInitCode) internal returns (address deployed) {
        deployed = LibSelfExtractingInitCode.deploySelfExtractingZRunInitCode(
            ZRuntime(LibAddresses.getZ()),
            _zip(unzippedInitCode),
            unzippedInitCode.length,
            bytes8(keccak256(unzippedInitCode))
        );
        summarize(deployed, unzippedInitCode.length);
    }

    function summarize(address deployed, uint256 unzippedSize) private {
        console.log(string(abi.encodePacked(
            'Deployed zipped contract to: ',
            vm.toString(deployed),
            ', Size: ', vm.toString(deployed.code.length),
            ', Unzipped size: ', vm.toString(unzippedSize),
            ', Compression: ', string(abi.encodePacked(vm.toString(100 - deployed.code.length * 100 / unzippedSize), '%'))
        )));
    }
}