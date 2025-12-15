// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ElitraVault } from "./ElitraVault.sol";
import { IBalanceUpdateHook } from "./interfaces/IBalanceUpdateHook.sol";
import { IRedemptionHook } from "./interfaces/IRedemptionHook.sol";

/// @title ElitraVaultFactory
/// @notice Deploys ElitraVault proxies deterministically (CREATE2) and seeds them in a single tx.
contract ElitraVaultFactory {
    using SafeERC20 for IERC20;

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

    constructor(address _implementation) {
        require(_implementation != address(0), "impl zero");
        implementation = _implementation;
    }

    /// @notice Deploy a vault proxy via CREATE2 and seed an initial deposit to set PPS.
    /// @param asset Underlying ERC20 asset.
    /// @param owner Vault owner/admin.
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
        IBalanceUpdateHook balanceHook,
        IRedemptionHook redemptionHook,
        string memory name,
        string memory symbol,
        bytes32 salt,
        uint256 initialSeed,
        address seedReceiver
    ) external returns (address payable vault, uint256 shares) {
        require(initialSeed > 0, "seed zero");
        require(address(asset) != address(0), "asset zero");
        require(owner != address(0), "owner zero");
        require(address(balanceHook) != address(0), "balance hook zero");
        require(address(redemptionHook) != address(0), "redemption hook zero");
        require(seedReceiver != address(0), "receiver zero");
        require(vaultBySalt[salt] == address(0), "salt used");

        bytes memory initData = abi.encodeWithSelector(
            ElitraVault.initialize.selector,
            asset,
            owner,
            balanceHook,
            redemptionHook,
            name,
            symbol
        );

        vault = payable(address(new ERC1967Proxy{salt: salt}(implementation, initData)));

        // Pull seed assets and deposit to set an initial PPS
        asset.safeTransferFrom(msg.sender, address(this), initialSeed);
        asset.forceApprove(vault, initialSeed);
        shares = ElitraVault(vault).deposit(initialSeed, seedReceiver);

        vaultBySalt[salt] = vault;
        allVaults.push(vault);
        vaultsByAsset[address(asset)].push(vault);

        emit VaultDeployed(vault, address(asset), owner, salt, initialSeed, seedReceiver);
    }

    /// @notice Predict the proxy address for a given salt and init params.
    /// @dev Helper for off-chain tooling / pre-approvals.
    function predictAddress(
        bytes32 salt,
        bytes memory initData
    ) external view returns (address predicted) {
        bytes memory creation = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implementation, initData)
        );
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(creation)));
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

