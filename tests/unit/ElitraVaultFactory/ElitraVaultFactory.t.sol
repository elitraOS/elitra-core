// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { ElitraVaultFactory } from "../../../src/ElitraVaultFactory.sol";
import { ElitraVault } from "../../../src/ElitraVault.sol";
import { ManualBalanceUpdateHook } from "../../../src/hooks/ManualBalanceUpdateHook.sol";
import { HybridRedemptionHook } from "../../../src/hooks/HybridRedemptionHook.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { FeeRegistryMock } from "../../mocks/FeeRegistryMock.sol";
import { IBalanceUpdateHook } from "../../../src/interfaces/IBalanceUpdateHook.sol";
import { IRedemptionHook } from "../../../src/interfaces/IRedemptionHook.sol";

contract ElitraVaultFactoryTest is Test {
    ElitraVaultFactory public factory;
    ElitraVault public implementation;
    ManualBalanceUpdateHook public balanceHook;
    HybridRedemptionHook public redemptionHook;
    FeeRegistryMock public feeRegistry;
    ERC20Mock public asset;

    address public owner;
    address public deployer;
    address public seedReceiver;
    bytes32 public salt;

    uint256 public constant BOOTSTRAP_AMOUNT = 1000000;
    uint256 public constant INITIAL_SEED = 2000000; // Must be > BOOTSTRAP_AMOUNT

    function setUp() public {
        owner = makeAddr("owner");
        deployer = makeAddr("deployer");
        seedReceiver = makeAddr("seedReceiver");
        salt = keccak256("test-salt");

        // Deploy mocks
        asset = new ERC20Mock();
        balanceHook = new ManualBalanceUpdateHook(owner);
        redemptionHook = new HybridRedemptionHook();
        feeRegistry = new FeeRegistryMock(0, owner);

        // Deploy implementation
        implementation = new ElitraVault();

        // Deploy factory
        vm.prank(deployer);
        factory = new ElitraVaultFactory(address(implementation));
    }

    // =========================================
    // CONSTRUCTOR TESTS
    // =========================================

    function test_Constructor_SetsImplementation() public {
        assertEq(address(factory.implementation()), address(implementation));
    }

    function test_Constructor_SetsOwnerToDeployer() public {
        assertEq(factory.owner(), deployer);
    }

    function test_Constructor_RevertsWhen_ZeroImplementation() public {
        vm.expectRevert("impl zero");
        new ElitraVaultFactory(address(0));
    }

    // =========================================
    // deployAndSeed() SUCCESS TESTS
    // =========================================

    function test_DeployAndSeed_DeploysVault() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act
        (address payable vault, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        assertTrue(vault != address(0));
        assertTrue(vault.code.length > 0);
    }

    function test_DeployAndSeed_MintsSharesToReceiver() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act
        (address payable vault, uint256 shares) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        assertGt(shares, 0);
        assertEq(ElitraVault(vault).balanceOf(seedReceiver), shares);
    }

    function test_DeployAndSeed_MintsBootstrapSharesToFactory() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act
        (address payable vault, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        uint256 factoryShares = ElitraVault(vault).balanceOf(address(factory));
        assertGt(factoryShares, 0);
    }

    function test_DeployAndSeed_TransfersAssetFromCaller() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        uint256 deployerBalanceBefore = asset.balanceOf(deployer);

        // Act
        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        assertEq(asset.balanceOf(deployer), deployerBalanceBefore - INITIAL_SEED);
    }

    function test_DeployAndSeed_SetsVaultOwner() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act
        (address payable vault, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        assertEq(ElitraVault(vault).owner(), owner);
    }

    function test_DeployAndSeed_SetsVaultParameters() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act
        (address payable vault, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        ElitraVault v = ElitraVault(vault);
        assertEq(address(v.asset()), address(asset));
        assertEq(address(v.balanceUpdateHook()), address(balanceHook));
        assertEq(address(v.redemptionHook()), address(redemptionHook));
        assertEq(v.name(), "Test Vault");
        assertEq(v.symbol(), "TVLT");
    }

    function test_DeployAndSeed_AddsToAllVaults() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        uint256 lengthBefore = factory.allVaultsLength();

        // Act
        (address payable vault, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        assertEq(factory.allVaultsLength(), lengthBefore + 1);
        assertEq(factory.allVaults(lengthBefore), vault);
    }

    function test_DeployAndSeed_AddsToVaultsByAsset() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act
        (address payable vault, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        address[] memory vaults = factory.getVaultsByAsset(address(asset));
        assertEq(vaults.length, 1);
        assertEq(vaults[0], vault);
    }

    function test_DeployAndSeed_MapsSaltToVault() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        bytes32 effectiveSalt = keccak256(abi.encodePacked(salt, deployer));

        // Act
        (address payable vault, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        assertEq(factory.vaultBySalt(effectiveSalt), vault);
    }

    function test_DeployAndSeed_EmitsVaultDeployedEvent() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            factory.owner(),
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT"
        );

        address predictedVault = factory.predictAddress(salt, deployer, initData);

        vm.expectEmit(true, true, true, true);
        emit ElitraVaultFactory.VaultDeployed(
            predictedVault,
            address(asset),
            owner,
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Act - deploy vault
        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );
    }

    function test_DeployAndSeed_MultipleVaultsForSameAsset() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED * 3);
        asset.approve(address(factory), INITIAL_SEED * 3);

        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");
        address receiver1 = makeAddr("receiver1");
        address receiver2 = makeAddr("receiver2");

        // Act
        (address vault1, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Vault 1",
            "VLT1",
            salt1,
            INITIAL_SEED,
            receiver1
        );

        (address vault2, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Vault 2",
            "VLT2",
            salt2,
            INITIAL_SEED,
            receiver2
        );

        // Assert
        address[] memory vaults = factory.getVaultsByAsset(address(asset));
        assertEq(vaults.length, 2);
        assertEq(vaults[0], vault1);
        assertEq(vaults[1], vault2);
        assertEq(factory.allVaultsLength(), 2);
    }

    // =========================================
    // deployAndSeed() REVERT TESTS
    // =========================================

    function test_DeployAndSeed_RevertsWhen_SeedTooSmall() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, BOOTSTRAP_AMOUNT);
        asset.approve(address(factory), BOOTSTRAP_AMOUNT);

        // Act & Assert
        vm.expectRevert("seed too small");
        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            BOOTSTRAP_AMOUNT,
            seedReceiver
        );
    }

    function test_DeployAndSeed_RevertsWhen_SeedEqualsBootstrap() public {
        // Arrange
        vm.startPrank(deployer);
        uint256 seedAmount = BOOTSTRAP_AMOUNT + 1; // Just one unit above
        asset.mint(deployer, seedAmount);
        asset.approve(address(factory), seedAmount);

        // This should still fail since must be >, not >=
        // Actually, looking at code: require(initialSeed > BOOTSTRAP_AMOUNT, "seed too small");
        // So seedAmount = BOOTSTRAP_AMOUNT + 1 should pass

        // Act & Assert - this should actually pass
        // But let's test the boundary with exactly BOOTSTRAP_AMOUNT
        asset.mint(deployer, BOOTSTRAP_AMOUNT);
        asset.approve(address(factory), BOOTSTRAP_AMOUNT);

        vm.expectRevert("seed too small");
        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            BOOTSTRAP_AMOUNT,
            seedReceiver
        );
    }

    function test_DeployAndSeed_RevertsWhen_AssetZero() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act & Assert
        vm.expectRevert("asset zero");
        factory.deployAndSeed(
            ERC20Mock(address(0)), // Zero address
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );
    }

    function test_DeployAndSeed_RevertsWhen_OwnerZero() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act & Assert
        vm.expectRevert("owner zero");
        factory.deployAndSeed(
            asset,
            address(0), // Zero owner
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );
    }

    function test_DeployAndSeed_RevertsWhen_BalanceHookZero() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act & Assert
        vm.expectRevert("balance hook zero");
        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            IBalanceUpdateHook(address(0)), // Zero hook
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );
    }

    function test_DeployAndSeed_RevertsWhen_RedemptionHookZero() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act & Assert
        vm.expectRevert("redemption hook zero");
        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            IRedemptionHook(address(0)), // Zero hook
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );
    }

    function test_DeployAndSeed_RevertsWhen_ReceiverZero() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act & Assert
        vm.expectRevert("receiver zero");
        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            address(0) // Zero receiver
        );
    }

    function test_DeployAndSeed_RevertsWhen_SaltAlreadyUsed() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED * 2);
        asset.approve(address(factory), INITIAL_SEED * 2);

        // Deploy first vault
        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Act & Assert - try to deploy with same salt
        vm.expectRevert("salt used");
        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault 2",
            "TVLT2",
            salt, // Same salt
            INITIAL_SEED,
            seedReceiver
        );
    }

    function test_DeployAndSeed_AllowsSameSaltForDifferentCaller() public {
        // Arrange
        address deployer2 = makeAddr("deployer2");

        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Deploy first vault with deployer
        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        vm.stopPrank();

        // Deploy second vault with deployer2 using same salt
        vm.startPrank(deployer2);
        asset.mint(deployer2, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // This should NOT revert - different caller = different effective salt
        (address vault2, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault 2",
            "TVLT2",
            salt, // Same salt but different caller
            INITIAL_SEED,
            seedReceiver
        );

        assertTrue(vault2 != address(0));
        assertEq(factory.allVaultsLength(), 2);
    }

    // =========================================
    // predictAddress() TESTS
    // =========================================

    function test_PredictAddress_ReturnsCorrectAddress() public {
        // Arrange
        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            factory.owner(),
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT"
        );

        // Act - predict before deployment
        address predicted = factory.predictAddress(salt, deployer, initData);

        // Deploy
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        (address actual, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        assertEq(predicted, actual);
    }

    function test_PredictAddress_DifferentForDifferentSalts() public {
        // Arrange
        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            factory.owner(),
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT"
        );

        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");

        // Act
        address predicted1 = factory.predictAddress(salt1, deployer, initData);
        address predicted2 = factory.predictAddress(salt2, deployer, initData);

        // Assert
        assertNotEq(predicted1, predicted2);
    }

    function test_PredictAddress_DifferentForDifferentCallers() public {
        // Arrange
        address deployer2 = makeAddr("deployer2");
        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            factory.owner(),
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT"
        );

        // Act
        address predicted1 = factory.predictAddress(salt, deployer, initData);
        address predicted2 = factory.predictAddress(salt, deployer2, initData);

        // Assert
        assertNotEq(predicted1, predicted2);
    }

    function test_PredictAddress_DifferentForDifferentInitData() public {
        // Arrange
        bytes memory initData1 = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            factory.owner(),
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Vault 1",
            "VLT1"
        );

        bytes memory initData2 = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            factory.owner(),
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Vault 2",
            "VLT2"
        );

        // Act
        address predicted1 = factory.predictAddress(salt, deployer, initData1);
        address predicted2 = factory.predictAddress(salt, deployer, initData2);

        // Assert
        assertNotEq(predicted1, predicted2);
    }

    // =========================================
    // allVaultsLength() TESTS
    // =========================================

    function test_AllVaultsLength_ReturnsZero_WhenNoVaults() public {
        assertEq(factory.allVaultsLength(), 0);
    }

    function test_AllVaultsLength_IncrementsWithEachDeployment() public {
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED * 3);
        asset.approve(address(factory), INITIAL_SEED * 3);

        assertEq(factory.allVaultsLength(), 0);

        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Vault 1",
            "VLT1",
            keccak256("salt1"),
            INITIAL_SEED,
            seedReceiver
        );
        assertEq(factory.allVaultsLength(), 1);

        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Vault 2",
            "VLT2",
            keccak256("salt2"),
            INITIAL_SEED,
            seedReceiver
        );
        assertEq(factory.allVaultsLength(), 2);

        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Vault 3",
            "VLT3",
            keccak256("salt3"),
            INITIAL_SEED,
            seedReceiver
        );
        assertEq(factory.allVaultsLength(), 3);
    }

    // =========================================
    // getVaultsByAsset() TESTS
    // =========================================

    function test_GetVaultsByAsset_ReturnsEmptyArray_WhenNoVaults() public {
        address[] memory vaults = factory.getVaultsByAsset(address(asset));
        assertEq(vaults.length, 0);
    }

    function test_GetVaultsByAsset_ReturnsOnlyVaultsForGivenAsset() public {
        // Arrange
        ERC20Mock asset2 = new ERC20Mock();

        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED * 2);
        asset.approve(address(factory), INITIAL_SEED * 2);
        asset2.mint(deployer, INITIAL_SEED);
        asset2.approve(address(factory), INITIAL_SEED);

        // Deploy vaults for asset1
        (address vault1, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Vault 1",
            "VLT1",
            keccak256("salt1"),
            INITIAL_SEED,
            seedReceiver
        );

        (address vault2, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Vault 2",
            "VLT2",
            keccak256("salt2"),
            INITIAL_SEED,
            seedReceiver
        );

        // Deploy vault for asset2
        factory.deployAndSeed(
            asset2,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Vault 3",
            "VLT3",
            keccak256("salt3"),
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        address[] memory asset1Vaults = factory.getVaultsByAsset(address(asset));
        assertEq(asset1Vaults.length, 2);
        assertEq(asset1Vaults[0], vault1);
        assertEq(asset1Vaults[1], vault2);

        address[] memory asset2Vaults = factory.getVaultsByAsset(address(asset2));
        assertEq(asset2Vaults.length, 1);
    }

    function test_GetVaultsByAsset_ReturnsEmptyForDifferentAsset() public {
        // Arrange
        ERC20Mock otherAsset = new ERC20Mock();

        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        // Assert
        address[] memory vaults = factory.getVaultsByAsset(address(otherAsset));
        assertEq(vaults.length, 0);
    }

    // =========================================
    // INTEGRATION TESTS
    // =========================================

    function test_Integration_DeployedVaultIsOperational() public {
        // Arrange
        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        // Act
        (address payable vault, uint256 shares) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );

        vm.stopPrank();

        // Assert - vault should be functional
        ElitraVault v = ElitraVault(vault);

        // Check basic vault properties
        assertEq(v.totalSupply(), shares + v.balanceOf(address(factory)));
        assertGt(v.totalAssets(), 0);

        // Check that receiver can interact with vault
        assertEq(v.balanceOf(seedReceiver), shares);

        // Check owner permissions
        assertEq(v.owner(), owner);
    }

    function test_Integration_VaultCanBeInteractedWith() public {
        // Arrange
        address user = makeAddr("user");
        uint256 depositAmount = 100000e6; // 100 USDC

        vm.startPrank(deployer);
        asset.mint(deployer, INITIAL_SEED);
        asset.approve(address(factory), INITIAL_SEED);

        (address payable vault, ) = factory.deployAndSeed(
            asset,
            owner,
            address(feeRegistry),
            balanceHook,
            redemptionHook,
            "Test Vault",
            "TVLT",
            salt,
            INITIAL_SEED,
            seedReceiver
        );
        vm.stopPrank();

        // Update balance to enable deposits (must be done by owner)
        vm.prank(owner);
        ElitraVault(vault).updateBalance(0);

        // Act - user deposits to vault
        vm.startPrank(user);
        asset.mint(user, depositAmount);
        asset.approve(vault, depositAmount);
        uint256 shares = ElitraVault(vault).deposit(depositAmount, user);

        // Assert
        assertGt(shares, 0);
        assertEq(ElitraVault(vault).balanceOf(user), shares);
    }
}
