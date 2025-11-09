// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ManualOracleAdapter_Base_Test } from "./Base.t.sol";
import { Errors } from "../../../src/libraries/Errors.sol";
import { IElitraVaultV2 } from "../../../src/interfaces/IElitraVaultV2.sol";

contract UpdateVaultBalance_Test is ManualOracleAdapter_Base_Test {
    function test_RevertWhen_CallerNotAuthorized() public {
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert("UNAUTHORIZED");
        adapter.updateVaultBalance(IElitraVaultV2(vault), 1000e6);
    }

    function test_WhenCallerAuthorized() public {
        // This will fail until we implement ManualOracleAdapter
        vm.prank(owner);
        bool success = adapter.updateVaultBalance(IElitraVaultV2(vault), 1000e6);
        assertTrue(success);
    }
}
