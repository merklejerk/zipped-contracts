// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../ZDeployBase.sol";

contract DeployRawZCall is ZDeployBase {
    function run() external {
        Z z = _getOrDeployZ();
        vm.broadcast(vm.envUint('DEPLOYER_KEY'));
        _zcallDeploy(vm.envBytes('UNZIPPED_INITCODE'), z);
    }
}
