// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/LibZRuntime.sol";
import "./ZipUtil.sol";

contract DeployBase is Script, ZipUtil {
    function _zcallDeploy(bytes memory unzippedInitCode) internal returns (address deployed) {
        deployed = LibZRuntime.deploySelfExtractingZCallInitCode(
            _getZ(),
            _zip(unzippedInitCode),
            unzippedInitCode.length,
            bytes8(keccak256(unzippedInitCode))
        );
        summarize(deployed, unzippedInitCode.length);
    }
    
    function _zrunDeploy(bytes memory unzippedInitCode) internal returns (address deployed) {
        deployed = LibZRuntime.deploySelfExtractingZRunInitCode(
            _getZ(),
            _zip(unzippedInitCode),
            unzippedInitCode.length,
            bytes8(keccak256(unzippedInitCode))
        );
        summarize(deployed, unzippedInitCode.length);
    }

    function _getZ() internal view returns (Z z) {
        if (block.chainid == 1) {
            z = Z(0x0000000000000000000000000000000000000000);
        } else if (block.chainid == 11155111) {
            z = Z(0x551F0E213dcb71f676558D8B0AB559d1cDD103F2);
        } else {
            z = Z(0x3198E681FB81462aeB42DD15b0C7BBe51D38750f);
        }
    }

    function summarize(address deployed, uint256 unzippedSize) private view {
        console.log(string(abi.encodePacked(
            'Deployed zipped contract to: ',
            vm.toString(deployed),
            ', Size: ', vm.toString(deployed.code.length),
            ', Unzipped size: ', vm.toString(unzippedSize),
            ', Compression: ', string(abi.encodePacked(vm.toString(100 - deployed.code.length * 100 / unzippedSize), '%'))
        )));
    }
}