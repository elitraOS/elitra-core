// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Types {
    struct Users {
        address payable admin;
        uint256 adminKey;
        address payable bob;
        uint256 bobKey;
        address payable alice;
        uint256 aliceKey;
    }
}
