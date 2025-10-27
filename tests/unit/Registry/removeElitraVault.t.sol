// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Registry_Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IElitraRegistry } from "src/interfaces/IElitraRegistry.sol";

contract RemoveElitraVault_Test is Registry_Base_Test {
    address internal mockAsset;
    address internal mockVault;

    function setUp() public override {
        super.setUp();

        // Create a mock asset (USDC)
        mockAsset = makeAddr("MockAsset");
        mockVault = createMockVault(mockAsset);
    }

    // ========================================= SUCCESS TESTS =========================================

    function test_removeElitraVault_Success() public {
        vm.startPrank({ msgSender: users.admin });

        // First add the vault
        registry.addElitraVault(mockVault);
        assertTrue(registry.isElitraVault(mockVault), "Vault should be registered");

        // Then remove it
        vm.expectEmit({ emitter: address(registry) });
        emit IElitraRegistry.ElitraVaultRemoved(mockAsset, mockVault);

        registry.removeElitraVault(mockVault);

        assertFalse(registry.isElitraVault(mockVault), "Vault should not be registered");
        vm.stopPrank();
    }

    function test_removeElitraVault_MultipleVaults() public {
        vm.startPrank({ msgSender: users.admin });

        address mockAsset2 = makeAddr("MockAsset2");
        address mockVault2 = createMockVault(mockAsset2);

        // Add both vaults
        registry.addElitraVault(mockVault);
        registry.addElitraVault(mockVault2);

        // Remove first vault
        registry.removeElitraVault(mockVault);
        assertFalse(registry.isElitraVault(mockVault), "First vault should not be registered");
        assertTrue(registry.isElitraVault(mockVault2), "Second vault should still be registered");

        // Check list
        address[] memory vaults = registry.listElitraVaults();
        assertEq(vaults.length, 1, "Should have 1 vault");
        assertEq(vaults[0], mockVault2, "Second vault should be in list");

        // Remove second vault
        registry.removeElitraVault(mockVault2);
        assertFalse(registry.isElitraVault(mockVault2), "Second vault should not be registered");

        // Check empty list
        vaults = registry.listElitraVaults();
        assertEq(vaults.length, 0, "Should have 0 vaults");

        vm.stopPrank();
    }

    // ========================================= FAILURE TESTS =========================================

    function test_removeElitraVault_ZeroAddress() public {
        vm.startPrank({ msgSender: users.admin });

        vm.expectRevert(Errors.Registry__VaultAddressZero.selector);
        registry.removeElitraVault(address(0));

        vm.stopPrank();
    }

    function test_removeElitraVault_VaultNotExists() public {
        vm.startPrank({ msgSender: users.admin });

        vm.expectRevert(abi.encodeWithSelector(Errors.Registry__VaultNotExists.selector, mockVault));
        registry.removeElitraVault(mockVault);

        vm.stopPrank();
    }

    function test_removeElitraVault_Unauthorized() public {
        vm.startPrank({ msgSender: users.admin });
        registry.addElitraVault(mockVault);
        vm.stopPrank();

        vm.startPrank({ msgSender: users.bob });

        vm.expectRevert();
        registry.removeElitraVault(mockVault);

        vm.stopPrank();
    }

    // ========================================= EDGE CASES =========================================

    function test_removeElitraVault_AlreadyRemoved() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addElitraVault(mockVault);
        assertTrue(registry.isElitraVault(mockVault), "Vault should be registered");

        // Remove vault
        registry.removeElitraVault(mockVault);
        assertFalse(registry.isElitraVault(mockVault), "Vault should not be registered");

        // Try to remove again
        vm.expectRevert(abi.encodeWithSelector(Errors.Registry__VaultNotExists.selector, mockVault));
        registry.removeElitraVault(mockVault);

        vm.stopPrank();
    }

    function test_removeElitraVault_EventEmission() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault first
        registry.addElitraVault(mockVault);

        // Remove vault and check event
        vm.expectEmit({ emitter: address(registry) });
        emit IElitraRegistry.ElitraVaultRemoved(mockAsset, mockVault);

        registry.removeElitraVault(mockVault);

        vm.stopPrank();
    }
}
