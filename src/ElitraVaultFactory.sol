// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ElitraVault } from "./ElitraVault.sol";
import { IBalanceUpdateHook } from "./interfaces/IBalanceUpdateHook.sol";
import { IRedemptionHook } from "./interfaces/IRedemptionHook.sol";

/// @title ElitraVaultFactory
/// @notice Deploys ElitraVault proxies deterministically (CREATE2) and seeds them in a single tx.
contract ElitraVaultFactory is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Bootstrap amount for dead shares to prevent inflation attacks.
    /// @dev These shares are held by the factory and never redeemed.
    uint256 public constant BOOTSTRAP_AMOUNT = 1000000; 

    /// @notice Vault implementation shared by all proxies.
    address public immutable implementation;

    /// @notice All deployed vault addresses (append-only).
    address[] public allVaults;

    /// @notice Mapping from salt to deployed vault address (0 if none).
    mapping(bytes32 salt => address vault) public vaultBySalt;

    /// @notice Mapping from asset to all vaults using that asset.
    mapping(address asset => address[] vaults) public vaultsByAsset;

    event VaultDeployed(
        address indexed vault,
        address indexed asset,
        address indexed owner,
        bytes32 salt,
        uint256 seedAssets,
        address seedReceiver
    );

    constructor(address _implementation) Ownable(msg.sender) {
        require(_implementation != address(0), "impl zero");
        implementation = _implementation;
    }

    /// @notice Deploy a vault proxy via CREATE2 and seed an initial deposit to set PPS.
    /// @dev Upgrade admin is set to the factory owner at deployment time.
    /// @param asset Underlying ERC20 asset.
    /// @param owner Vault owner/admin.
    /// @param feeRegistry Fee registry for protocol fee rate.
    /// @param balanceHook Balance update hook.
    /// @param redemptionHook Redemption hook.
    /// @param name Vault token name.
    /// @param symbol Vault token symbol.
    /// @param salt CREATE2 salt to derive the vault address.
    /// @param initialSeed Amount of assets to seed (must be > 0).
    /// @param seedReceiver Recipient of the seeded shares.
    function deployAndSeed(
        IERC20 asset,
        address owner,
        address feeRegistry,
        IBalanceUpdateHook balanceHook,
        IRedemptionHook redemptionHook,
        string memory name,
        string memory symbol,
        bytes32 salt,
        uint256 initialSeed,
        address seedReceiver
    ) external returns (address payable vault, uint256 shares) {
        require(initialSeed > BOOTSTRAP_AMOUNT, "seed too small");
        require(address(asset) != address(0), "asset zero");
        require(owner != address(0), "owner zero");
        require(address(balanceHook) != address(0), "balance hook zero");
        require(address(redemptionHook) != address(0), "redemption hook zero");
        require(seedReceiver != address(0), "receiver zero");
        require(vaultBySalt[salt] == address(0), "salt used");

        // Derive caller-specific salt to prevent front-running
        bytes32 effectiveSalt = keccak256(abi.encodePacked(salt, msg.sender));

        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            owner(),
            feeRegistry,
            balanceHook,
            redemptionHook,
            name,
            symbol
        );

        vault = payable(address(new ERC1967Proxy{salt: effectiveSalt}(implementation, initData)));

        // Pull seed assets and deposit to set an initial PPS
        asset.safeTransferFrom(msg.sender, address(this), initialSeed);
        asset.forceApprove(vault, initialSeed);

        // Dead shares: mint bootstrap shares to factory to prevent inflation attacks
        // Also validates no share manipulation occurred (front-run donation attack)
        uint256 bootstrapShares = ElitraVault(vault).deposit(BOOTSTRAP_AMOUNT, address(this));
        
        // Normalize to 1e18 base to handle different asset/share decimals
        uint8 shareDecimals = ElitraVault(vault).decimals();
        uint8 assetDecimals = IERC20Metadata(address(asset)).decimals();
        uint256 normalizedShares = bootstrapShares * 1e18 / (10 ** shareDecimals);
        uint256 normalizedExpected = BOOTSTRAP_AMOUNT * 1e18 / (10 ** assetDecimals);
        require(normalizedShares >= normalizedExpected * 99 / 100, "share manipulation");

        // Remaining shares go to seedReceiver
        shares = ElitraVault(vault).deposit(initialSeed - BOOTSTRAP_AMOUNT, seedReceiver);

        vaultBySalt[salt] = vault;
        allVaults.push(vault);
        vaultsByAsset[address(asset)].push(vault);

        emit VaultDeployed(vault, address(asset), owner, salt, initialSeed, seedReceiver);
    }

    /// @notice Predict the proxy address for a given salt, caller, and init params.
    /// @dev Helper for off-chain tooling / pre-approvals.
    function predictAddress(
        bytes32 salt,
        address caller,
        bytes memory initData
    ) external view returns (address predicted) {
        // Derive caller-specific salt (must match deployAndSeed logic)
        bytes32 effectiveSalt = keccak256(abi.encodePacked(salt, caller));
        bytes memory creation = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implementation, initData)
        );
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), effectiveSalt, keccak256(creation)));
        predicted = address(uint160(uint256(hash)));
    }

    /// @notice Number of vaults deployed by this factory.
    function allVaultsLength() external view returns (uint256) {
        return allVaults.length;
    }

    /// @notice Get all vaults for a given asset.
    function getVaultsByAsset(address asset) external view returns (address[] memory) {
        return vaultsByAsset[asset];
    }

}
