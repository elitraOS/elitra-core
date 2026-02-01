// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { HybridRedemptionHook } from "../../../src/hooks/HybridRedemptionHook.sol";

contract HybridRedemptionHook_Base_Test is Test {
    HybridRedemptionHook public strategy;
    address public vault;

    function setUp() public virtual {
        strategy = new HybridRedemptionHook();
        vault = makeAddr("vault");
    }
}
