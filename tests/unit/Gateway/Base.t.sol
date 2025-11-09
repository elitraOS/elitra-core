// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";

import { Authority } from "src/base/AuthUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { Users } from "../../utils/Types.sol";
import { Utils } from "../../utils/Utils.sol";
import { Events } from "../../utils/Events.sol";
import { Constants } from "../../utils/Constants.sol";
import { MockAuthority } from "../../mocks/MockAuthority.sol";

import { ElitraGateway } from "src/ElitraGateway.sol";
import { ElitraVault } from "src/ElitraVault.sol";
import { ElitraRegistry } from "src/ElitraRegistry.sol";
import { IOracleAdapter } from "src/interfaces/IOracleAdapter.sol";
import { IRedemptionStrategy } from "src/interfaces/IRedemptionStrategy.sol";
import { HybridRedemptionStrategy } from "src/strategies/HybridRedemptionStrategy.sol";
import { ManualOracleAdapter } from "src/adapters/ManualOracleAdapter.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";

/// @notice Base test contract with common logic needed by all ElitraGateway tests.

abstract contract Gateway_Base_Test is Test, Events, Utils, Constants {
    using Math for uint256;

    // ========================================= VARIABLES =========================================
    Users internal users;

    // ====================================== TEST CONTRACTS =======================================
    IERC20 internal usdc;
    ElitraVault internal elitraVault;
    ElitraGateway internal gateway;
    Authority internal authority;
    ElitraRegistry internal registry;
    IOracleAdapter internal oracleAdapter;
    IRedemptionStrategy internal redemptionStrategy;

    // Dummy address for testing unregistered vaults
    address internal constant DUMMY_VAULT = address(0x1234567890123456789012345678901234567890);

    // ====================================== SET-UP FUNCTION ======================================
    function setUp() public virtual {
        // Create the admin.
        users.admin = payable(makeAddr({ name: "Admin" }));
        vm.startPrank({ msgSender: users.admin });

        // Deploy mock USDC
        usdc = new ERC20Mock();
        vm.label({ account: address(usdc), newLabel: "USDC" });

        deployContracts();

        // Create users for testing.
        (users.bob, users.bobKey) = createUser("Bob");
        (users.alice, users.aliceKey) = createUser("Alice");
    }

    // ====================================== HELPERS =======================================

    /// @dev Approves the protocol contracts to spend the user's USDC and shares.
    function approveProtocol(address from) internal {
        resetPrank({ msgSender: from });
        usdc.approve({ spender: address(gateway), value: UINT256_MAX });
        usdc.approve({ spender: address(elitraVault), value: UINT256_MAX });
        elitraVault.approve({ spender: address(gateway), value: UINT256_MAX });
        elitraVault.approve({ spender: address(elitraVault), value: UINT256_MAX });
    }

    /// @dev Generates a user, labels its address, funds it with test assets, and approves the protocol contracts.
    function createUser(string memory name) internal returns (address payable, uint256) {
        (address user, uint256 key) = makeAddrAndKey(name);
        vm.deal({ account: user, newBalance: 100 ether });
        ERC20Mock(address(usdc)).mint(user, 1_000_000e18);
        approveProtocol({ from: user });
        return (payable(user), key);
    }

    /// @dev Deploys all the necessary contracts
    function deployContracts() internal {
        // Deploy ElitraRegistry
        ElitraRegistry registryImpl = new ElitraRegistry();
        bytes memory registryData =
            abi.encodeWithSelector(ElitraRegistry.initialize.selector, users.admin, Authority(address(0)));
        TransparentUpgradeableProxy registryProxy =
            new TransparentUpgradeableProxy(address(registryImpl), users.admin, registryData);
        registry = ElitraRegistry(payable(address(registryProxy)));

        // Deploy oracle and redemption strategy
        oracleAdapter = new ManualOracleAdapter(users.admin);
        redemptionStrategy = new HybridRedemptionStrategy();

        // Deploy ElitraVault
        ElitraVault vaultImpl = new ElitraVault();
        bytes memory vaultData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            usdc,
            users.admin,
            oracleAdapter,
            redemptionStrategy,
            "Elitra USDC Vault",
            "eUSDC"
        );
        TransparentUpgradeableProxy vaultProxy =
            new TransparentUpgradeableProxy(address(vaultImpl), users.admin, vaultData);
        elitraVault = ElitraVault(payable(address(vaultProxy)));

        // Deploy ElitraGateway
        ElitraGateway gatewayImpl = new ElitraGateway();
        bytes memory data = abi.encodeWithSelector(ElitraGateway.initialize.selector, address(registry));
        gateway = ElitraGateway(payable(new TransparentUpgradeableProxy(address(gatewayImpl), users.admin, data)));

        // Set up authority for registry
        authority = new MockAuthority(users.admin, Authority(address(0)));
        registry.setAuthority({ newAuthority: authority });

        MockAuthority(address(authority)).setUserRole(users.admin, ADMIN_ROLE, true);

        // Add the vault to the registry
        registry.addElitraVault(address(elitraVault));

        // Label the contracts
        vm.label({ account: address(gateway), newLabel: "ElitraGateway" });
        vm.label({ account: address(registry), newLabel: "ElitraRegistry" });
        vm.label({ account: address(elitraVault), newLabel: "elitraUSDCVault" });
    }
}
