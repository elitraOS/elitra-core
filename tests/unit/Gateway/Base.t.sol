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

    // Dummy address for testing unregistered vaults
    address internal constant DUMMY_VAULT = address(0x1234567890123456789012345678901234567890);

    // ====================================== SET-UP FUNCTION ======================================
    function setUp() public virtual {
        vm.createSelectFork({
            blockNumber: 29_066_193,
            urlOrAlias: vm.envOr("BASE_RPC_URL", string("https://base.llamarpc.com"))
        });

        // USDC (https://basescan.org/token/0x833589fcd6edb6e08f4c7c32d4f71b54bda02913)
        usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

        // Use existing ElitraVault deployment
        elitraVault = ElitraVault(payable(0x0000000f2eB9f69274678c76222B35eEc7588a65));

        // Label the base test contracts.
        vm.label({ account: address(usdc), newLabel: "USDC" });
        vm.label({ account: address(elitraVault), newLabel: "elitraUSDCVault" });

        // Create the admin.
        users.admin = payable(makeAddr({ name: "Admin" }));
        vm.startPrank({ msgSender: users.admin });

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
        deal({ token: address(usdc), to: user, give: 1_000_000e6, adjust: true });
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

        // Deploy ElitraGateway
        ElitraGateway gatewayImpl = new ElitraGateway();
        bytes memory data = abi.encodeWithSelector(ElitraGateway.initialize.selector, address(registry));
        gateway = ElitraGateway(payable(new TransparentUpgradeableProxy(address(gatewayImpl), users.admin, data)));

        // Set up authority for registry
        authority = new MockAuthority(users.admin, Authority(address(0)));
        registry.setAuthority({ newAuthority: authority });

        MockAuthority(address(authority)).setUserRole(users.admin, ADMIN_ROLE, true);

        // Add the existing vault to the registry
        registry.addElitraVault(address(elitraVault));

        // Label the contracts
        vm.label({ account: address(gateway), newLabel: "ElitraGateway" });
        vm.label({ account: address(registry), newLabel: "ElitraRegistry" });
    }
}
