// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import "forge-std/Script.sol";
import { ElitraEscrow } from "src/ElitraEscrow.sol";
import { BaseScript } from "./Base.s.sol";

contract Deploy is BaseScript {
    address VAULT = address(0x0000000f2eB9f69274678c76222B35eEc7588a65);

    function run() public broadcast returns (ElitraEscrow escrow) {
        require(VAULT != address(0), "No vault address set");
        escrow = new ElitraEscrow(VAULT);
    }
}
