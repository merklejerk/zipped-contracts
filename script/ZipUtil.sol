// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "forge-std/Script.sol";

contract ZipUtil is Script {
    function _zip(bytes memory data) internal returns (bytes memory zipped) {
        string memory compressScript = './compress.py';
        if (!_doesFileExist(compressScript, 'text/x-script.python')) {
            compressScript = './lib/zipped-contracts/compress.py';
        }
        string[] memory args = new string[](4);
        args[0] = 'env';
        args[1] = 'python3';
        args[2] = compressScript;
        args[3] = vm.toString(data);
        return vm.ffi(args);
    }

    function _doesFileExist(string memory path, string memory mimeType) private returns (bool) {
        string[] memory args = new string[](4);
        args[0] = 'file';
        args[1] = '--mime-type';
        args[2] = '-b';
        args[3] = path;
        return keccak256(vm.ffi(args)) == keccak256(bytes(mimeType));
    }
}
