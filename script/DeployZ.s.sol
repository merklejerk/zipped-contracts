// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "src/Z.sol";

contract DeployZ is Script {
    function run() public {
        vm.broadcast(vm.envUint('DEPLOYER_KEY'));
        Z z = new Z();
        console.log('Deployed to:', address(z));
        console.log('Size:', address(z).code.length);
    }
}
