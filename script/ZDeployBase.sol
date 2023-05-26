// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/LibZRuntime.sol";
import "./ZipUtil.sol";

contract ZDeployBase is Script, ZipUtil {
    function _zcallDeploy(bytes memory unzippedInitCode) internal returns (address deployed) {
        return _zcallDeploy(unzippedInitCode, Z(address(0)));
    }

    function _zcallDeploy(bytes memory unzippedInitCode, Z z) internal returns (address deployed) {
        deployed = LibZRuntime.deploySelfExtractingZCallInitCode(
            _getValidExistingZ(z),
            _zip(unzippedInitCode),
            unzippedInitCode.length,
            keccak256(unzippedInitCode)
        );
        summarize(deployed, unzippedInitCode.length);
    }

    function _zrunDeploy(bytes memory unzippedInitCode) internal returns (address deployed) {
        return _zrunDeploy(unzippedInitCode, Z(address(0)));
    }
    
    function _zrunDeploy(bytes memory unzippedInitCode, Z z) internal returns (address deployed) {
        deployed = LibZRuntime.deploySelfExtractingZRunInitCode(
            _getValidExistingZ(z),
            _zip(unzippedInitCode),
            unzippedInitCode.length,
            keccak256(unzippedInitCode)
        );
        summarize(deployed, unzippedInitCode.length);
    }

    function _getOrDeployZ() internal returns (Z z) {
        z = _getExistingZ();
        if (address(z) == address(0) || address(z).code.length == 0) {
            console.log(string(abi.encodePacked(
                'No available Z runtime for current chain (',
                vm.toString(block.chainid),
                '). Deploying one...'
            )));
            z = new Z();
            console.log('Deployed Z runtime to ', address(z));
        }
    }

    function _getExistingZ() internal view returns (Z z) {
        if (block.chainid == 1) {
            z = Z(0x0000000000000000000000000000000000000000);
        } else if (block.chainid == 11155111) {
            z = Z(0xcA64D4225804F2Ae069760CB5fF2F1D8BaC1C2f9);
        } else if (block.chainid == 5) {
            z = Z(0xcA64D4225804F2Ae069760CB5fF2F1D8BaC1C2f9);
        }
    }

    function _getValidExistingZ(Z z_) private view returns (Z z) {
        z = address(z_) == address(0) ? _getExistingZ() : z_;
        if (address(z) == address(0)) {
            revert(string(abi.encodePacked(
                'No known Z runtime deployment for the current chain (',
                vm.toString(block.chainid),
                '). Pass it in explicitly.'
            )));
        }
    }

    function summarize(address deployed, uint256 unzippedSize) private view {
        console.log(string(abi.encodePacked(
            'Deployed zipped contract to: ',
            vm.toString(deployed),
            ', Size: ', vm.toString(deployed.code.length),
            ', Unzipped size: ', vm.toString(unzippedSize),
            ', Compression: ', string(abi.encodePacked(vm.toString(100 - int256(deployed.code.length * 100 / unzippedSize)), '%'))
        )));
    }
}