// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Registry_Base_Test } from "./Base.t.sol";
import { Errors } from "src/libraries/Errors.sol";
import { IElitraRegistry } from "src/interfaces/IElitraRegistry.sol";

contract AddElitraVault_Test is Registry_Base_Test {
    address internal mockAsset;
    address internal mockVault;

    function setUp() public override {
        super.setUp();

        // Create a mock asset (USDC)
        mockAsset = makeAddr("MockAsset");
        mockVault = createMockVault(mockAsset);
    }

    // ========================================= SUCCESS TESTS =========================================

    function test_addElitraVault_Success() public {
        vm.startPrank({ msgSender: users.admin });

        vm.expectEmit({ emitter: address(registry) });
        emit IElitraRegistry.ElitraVaultAdded(mockAsset, mockVault);

        registry.addElitraVault(mockVault);

        assertTrue(registry.isElitraVault(mockVault), "Vault should be registered");
        vm.stopPrank();
    }

    function test_addElitraVault_MultipleVaults() public {
        vm.startPrank({ msgSender: users.admin });

        address mockAsset2 = makeAddr("MockAsset2");
        address mockVault2 = createMockVault(mockAsset2);

        // Add first vault
        registry.addElitraVault(mockVault);
        assertTrue(registry.isElitraVault(mockVault), "First vault should be registered");

        // Add second vault
        registry.addElitraVault(mockVault2);
        assertTrue(registry.isElitraVault(mockVault2), "Second vault should be registered");

        // Check both are in the list
        address[] memory vaults = registry.listElitraVaults();
        assertEq(vaults.length, 2, "Should have 2 vaults");
        assertEq(vaults[0], mockVault, "First vault should be in list");
        assertEq(vaults[1], mockVault2, "Second vault should be in list");

        vm.stopPrank();
    }

    // ========================================= FAILURE TESTS =========================================

    function test_addElitraVault_ZeroAddress() public {
        vm.startPrank({ msgSender: users.admin });

        vm.expectRevert(Errors.Registry__VaultAddressZero.selector);
        registry.addElitraVault(address(0));

        vm.stopPrank();
    }

    function test_addElitraVault_VaultAlreadyExists() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault first time
        registry.addElitraVault(mockVault);
        assertTrue(registry.isElitraVault(mockVault), "Vault should be registered");

        // Try to add the same vault again
        vm.expectRevert(abi.encodeWithSelector(Errors.Registry__VaultAlreadyExists.selector, mockVault));
        registry.addElitraVault(mockVault);

        vm.stopPrank();
    }

    function test_addElitraVault_Unauthorized() public {
        vm.startPrank({ msgSender: users.bob });

        vm.expectRevert();
        registry.addElitraVault(mockVault);

        vm.stopPrank();
    }

    // ========================================= EDGE CASES =========================================

    function test_addElitraVault_AfterRemoval() public {
        vm.startPrank({ msgSender: users.admin });

        // Add vault
        registry.addElitraVault(mockVault);
        assertTrue(registry.isElitraVault(mockVault), "Vault should be registered");

        // Remove vault
        registry.removeElitraVault(mockVault);
        assertFalse(registry.isElitraVault(mockVault), "Vault should not be registered");

        // Add vault again
        vm.expectEmit({ emitter: address(registry) });
        emit IElitraRegistry.ElitraVaultAdded(mockAsset, mockVault);
        registry.addElitraVault(mockVault);
        assertTrue(registry.isElitraVault(mockVault), "Vault should be registered again");

        vm.stopPrank();
    }

    function test_addElitraVault_EventEmission() public {
        vm.startPrank({ msgSender: users.admin });

        vm.expectEmit({ emitter: address(registry) });
        emit IElitraRegistry.ElitraVaultAdded(mockAsset, mockVault);

        registry.addElitraVault(mockVault);

        vm.stopPrank();
    }
}
