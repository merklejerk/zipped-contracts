// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

contract ZipUtil is Script {
    function _zip(bytes memory data) internal returns (bytes memory zipped) {
        string[] memory args = new string[](4);
        args[0] = 'env';
        args[1] = 'python';
        args[2] = 'compress.py';
        args[3] = vm.toString(data);
        return abi.decode(vm.ffi(args), (bytes));
    }
}
