// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { HybridRedemptionStrategy } from "../../../src/strategies/HybridRedemptionStrategy.sol";
import { IElitraVaultV2 } from "../../../src/interfaces/IElitraVaultV2.sol";

contract HybridRedemptionStrategy_Base_Test is Test {
    HybridRedemptionStrategy public strategy;
    address public vault;

    function setUp() public virtual {
        strategy = new HybridRedemptionStrategy();
        vault = makeAddr("vault");
    }
}
