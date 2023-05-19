// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "src/Z.sol";

library LibAddresses {
    function getZ() internal view returns (Z z) {
        if (block.chainid == 1) {
            z = Z(0x0000000000000000000000000000000000000000);
        } else if (block.chainid == 11155111) {
            z = Z(0x551F0E213dcb71f676558D8B0AB559d1cDD103F2);
        } else {
            z = Z(0x3198E681FB81462aeB42DD15b0C7BBe51D38750f);
        }
    }
}