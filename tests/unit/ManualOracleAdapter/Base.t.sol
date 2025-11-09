// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { ManualOracleAdapter } from "../../../src/adapters/ManualOracleAdapter.sol";
import { IElitraVaultV2 } from "../../../src/interfaces/IElitraVaultV2.sol";

contract ManualOracleAdapter_Base_Test is Test {
    ManualOracleAdapter public adapter;
    address public owner;
    address public vault;

    function setUp() public virtual {
        owner = makeAddr("owner");
        vault = makeAddr("vault");

        adapter = new ManualOracleAdapter(owner);
    }
}
