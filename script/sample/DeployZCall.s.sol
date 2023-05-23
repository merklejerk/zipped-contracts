// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../DeployBase.sol";

contract HelloWorld {
    string public message;
    constructor(string memory message_) {
        message = message_;
    }
}

interface IHelloWorld {
    function message() external /* view */ returns (string memory);
}

contract DeployZCall is DeployBase {
    function run() external {
        vm.broadcast(vm.envUint('DEPLOYER_KEY'));
        IHelloWorld deployed = IHelloWorld(_zcallDeploy(abi.encodePacked(
            type(HelloWorld).creationCode,
            // Constructor args are just ABI-encoded and appended to initcode.
            abi.encode("Hello, world!")
        )));
        // Test it.
        console.log(deployed.message());
    }
}
