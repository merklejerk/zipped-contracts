// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./DeployBase.sol";

contract DeployRawZCall is DeployBase {
    function run() external {
        vm.broadcast(vm.envUint('DEPLOYER_KEY'));
        _zcallDeploy(vm.envBytes('UNZIPPED_INITCODE'));
    }
}
