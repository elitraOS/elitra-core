// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Registry_Base_Test } from "./Base.t.sol";

contract IsElitraVault_Test is Registry_Base_Test {
    address internal mockAsset;
    address internal mockVault;
    address internal mockAsset2;
    address internal mockVault2;

    function setUp() public override {
        super.setUp();

        // Create mock assets and vaults
        mockAsset = makeAddr("MockAsset");
        mockVault = createMockVault(mockAsset);
        mockAsset2 = makeAddr("MockAsset2");
        mockVault2 = createMockVault(mockAsset2);
    }

    // ========================================= SUCCESS TESTS =========================================

    function test_isElitraVault_RegisteredVault() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addElitraVault(mockVault);

        // Check if vault is registered
        assertTrue(registry.isElitraVault(mockVault), "Registered vault should return true");

        vm.stopPrank();
    }

    function test_isElitraVault_UnregisteredVault() public view {
        // Check if unregistered vault returns false
        assertFalse(registry.isElitraVault(mockVault), "Unregistered vault should return false");
    }

    function test_isElitraVault_ZeroAddress() public view {
        // Check if zero address returns false
        assertFalse(registry.isElitraVault(address(0)), "Zero address should return false");
    }

    function test_isElitraVault_MultipleVaults() public {
        vm.startPrank({ msgSender: users.admin });

        // Add both vaults
        registry.addElitraVault(mockVault);
        registry.addElitraVault(mockVault2);

        // Check both are registered
        assertTrue(registry.isElitraVault(mockVault), "First vault should be registered");
        assertTrue(registry.isElitraVault(mockVault2), "Second vault should be registered");

        // Check random address is not registered
        address randomAddress = makeAddr("RandomAddress");
        assertFalse(registry.isElitraVault(randomAddress), "Random address should not be registered");

        vm.stopPrank();
    }

    // ========================================= EDGE CASES =========================================

    function test_isElitraVault_AfterRemoval() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addElitraVault(mockVault);
        assertTrue(registry.isElitraVault(mockVault), "Vault should be registered");

        // Remove vault
        registry.removeElitraVault(mockVault);
        assertFalse(registry.isElitraVault(mockVault), "Vault should not be registered after removal");

        vm.stopPrank();
    }

    function test_isElitraVault_ReAddAfterRemoval() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addElitraVault(mockVault);
        assertTrue(registry.isElitraVault(mockVault), "Vault should be registered");

        // Remove vault
        registry.removeElitraVault(mockVault);
        assertFalse(registry.isElitraVault(mockVault), "Vault should not be registered after removal");

        // Add vault again
        registry.addElitraVault(mockVault);
        assertTrue(registry.isElitraVault(mockVault), "Vault should be registered again");

        vm.stopPrank();
    }

    function test_isElitraVault_NonExistentContract() public view {
        // Check if non-existent contract address returns false
        address nonExistentContract = address(0x1234567890123456789012345678901234567890);
        assertFalse(registry.isElitraVault(nonExistentContract), "Non-existent contract should return false");
    }

    function test_isElitraVault_AnyUserCanCall() public {
        vm.startPrank({ msgSender: users.admin });
        registry.addElitraVault(mockVault);
        vm.stopPrank();

        // Bob should be able to call isElitraVault
        vm.startPrank({ msgSender: users.bob });
        assertTrue(registry.isElitraVault(mockVault), "Bob should be able to check if vault is registered");
        vm.stopPrank();

        // Alice should be able to call isElitraVault
        vm.startPrank({ msgSender: users.alice });
        assertTrue(registry.isElitraVault(mockVault), "Alice should be able to check if vault is registered");
        vm.stopPrank();
    }
}
