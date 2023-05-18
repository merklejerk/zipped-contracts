// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

library LibContractStorage {
    function store(bytes memory data) internal returns (address a) {
        return address(new Storage(data));
    }

    function unstore(address at) internal view returns (bytes memory data) {
        uint256 len = at.code.length - 1;
        data = new bytes(len);
        assembly { extcodecopy(at, add(data, 0x20), 1, len) }
    }
}

contract Storage {
    constructor(bytes memory data) {
        assembly {
            let len := add(mload(data), 1)
            data := add(data, 0x1F)
            mstore8(data, 0xFE)
            return(data, len)
        }
    }
}