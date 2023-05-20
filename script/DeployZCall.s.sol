// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./DeployBase.sol";

contract HelloWorld {
    string public message = "hello, world!";
}

contract DeployZCall is DeployBase {
    function run() external {
        vm.broadcast(vm.envUint('DEPLOYER_KEY'));
        _zcallDeploy(type(HelloWorld).creationCode);
    }
}
