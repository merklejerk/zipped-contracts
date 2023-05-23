// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../DeployBase.sol";

contract HelloWorld {
    constructor(bool isDay) {
        string memory mess = isDay ? "good day!" : "good night!";
        assembly { return(add(mess, 0x20), mload(mess)) }
    }
}

interface IHelloWorld {
    // It doesn't matter what this function is named. The constructor
    // will always be called.
    function exec(bool isDay) external /* view */ returns (string memory);
}

contract DeployZRun is DeployBase {
    function run() external {
        vm.broadcast(vm.envUint('DEPLOYER_KEY'));
        IHelloWorld deployed = IHelloWorld(_zrunDeploy(abi.encodePacked(
            type(HelloWorld).creationCode
        )));
        // Test it.
        console.log(deployed.exec(true));
        console.log(deployed.exec(false));
    }
}
