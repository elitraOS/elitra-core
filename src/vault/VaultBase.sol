// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "../libraries/Errors.sol";
import { IVaultBase, Call } from "../interfaces/IVaultBase.sol";
import { ITransactionGuard } from "../interfaces/ITransactionGuard.sol";
import { Compatible } from "./Compatible.sol";
import { AuthUpgradeable, Authority } from "./AuthUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { EnumerableSetUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title VaultBase
/// @author Elitra
/// @notice Base contract for Vaults and SubVaults providing auth, pause, and management features
abstract contract VaultBase is AuthUpgradeable, PausableUpgradeable, UUPSUpgradeable, Compatible, IVaultBase {
    using Address for address;
    using SafeERC20 for IERC20;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    /// @custom:storage-location erc7201:elitra.storage.vaultbase
    struct VaultBaseStorage {
        mapping(address target => ITransactionGuard guard) guards;
        EnumerableSetUpgradeable.AddressSet trustedTargets;
        EnumerableSetUpgradeable.AddressSet guardedTargets;
    }

    // keccak256(abi.encode(uint256(keccak256("elitra.storage.vaultbase")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VAULT_BASE_STORAGE_LOCATION =
        0x28c4b052a520676d101ba86c6252692dd22c3eb0f745f659491e2b37c29b8100;

    /// @notice Get the storage struct for VaultBase
    /// @return vaultBaseStorage The storage struct
    function _getVaultBaseStorage() private pure returns (VaultBaseStorage storage vaultBaseStorage) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            vaultBaseStorage.slot := VAULT_BASE_STORAGE_LOCATION
        }
    }

    /// @notice Disable initializers (for proxy pattern safety)
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the vault base
    /// @param _owner The address of the owner
    function __VaultBase_init(address _owner) internal onlyInitializing {
        __Auth_init(_owner, Authority(address(0)));
        __Pausable_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Pause the vault
    function pause() public virtual requiresAuth {
        _pause();
    }

    /// @notice Unpause the vault
    function unpause() public virtual requiresAuth {
        _unpause();
    }

    /// @notice Sets the guard for a specific target
    /// @param target The target contract address
    /// @param guard The guard contract address
    function setGuard(address target, address guard) external virtual requiresAuth {
        VaultBaseStorage storage vaultBaseStorage = _getVaultBaseStorage();
        vaultBaseStorage.guards[target] = ITransactionGuard(guard);
        vaultBaseStorage.guardedTargets.add(target);
        emit GuardUpdated(target, guard);
    }

    /// @notice Removes the guard for a specific target
    /// @param target The target contract address
    function removeGuard(address target) external virtual requiresAuth {
        VaultBaseStorage storage vaultBaseStorage = _getVaultBaseStorage();
        delete vaultBaseStorage.guards[target];
        vaultBaseStorage.guardedTargets.remove(target);
        emit GuardRemoved(target);
    }

    /// @notice Returns the guard for a specific target
    /// @param target The target contract address
    /// @return The guard contract
    function guards(address target) external view override returns (ITransactionGuard) {
        VaultBaseStorage storage vaultBaseStorage = _getVaultBaseStorage();
        return vaultBaseStorage.guards[target];
    }

    /// @notice Sets a target as trusted or untrusted
    /// @param target The target contract address
    /// @param isTrusted Whether the target is trusted
    function setTrustedTarget(address target, bool isTrusted) external virtual requiresAuth {
        VaultBaseStorage storage vaultBaseStorage = _getVaultBaseStorage();
        if (isTrusted) {
            vaultBaseStorage.trustedTargets.add(target);
        } else {
            vaultBaseStorage.trustedTargets.remove(target);
        }
        emit TrustedTargetUpdated(target, isTrusted);
    }

    /// @notice Returns whether a target is trusted
    /// @param target The target contract address
    /// @return Whether the target is trusted
    function isTrustedTarget(address target) external view override returns (bool) {
        VaultBaseStorage storage vaultBaseStorage = _getVaultBaseStorage();
        return vaultBaseStorage.trustedTargets.contains(target);
    }

    /// @notice Returns the list of trusted targets
    /// @return The list of trusted targets
    function getTrustedTargets() external view returns (address[] memory) {
        VaultBaseStorage storage vaultBaseStorage = _getVaultBaseStorage();
        return vaultBaseStorage.trustedTargets.values();
    }

    /// @notice Returns the list of guarded targets
    /// @return The list of guarded targets
    function getGuardedTargets() external view returns (address[] memory) {
        VaultBaseStorage storage vaultBaseStorage = _getVaultBaseStorage();
        return vaultBaseStorage.guardedTargets.values();
    }

    /// @notice Execute a call to a target contract
    /// @param target The address of the target contract
    /// @param data The calldata to execute
    /// @param value The amount of ETH to send
    /// @return result The return data of the call
    function _manage(
        address target,
        bytes calldata data,
        uint256 value
    )
        internal
        requiresAuth
        returns (bytes memory result)
    {
        VaultBaseStorage storage vaultBaseStorage = _getVaultBaseStorage();

        ITransactionGuard guard = vaultBaseStorage.guards[target];

        if (address(guard) != address(0)) {
            if (!guard.validate(msg.sender, data, value)) {
                revert Errors.TransactionValidationFailed(target);
            }
        } else if (!vaultBaseStorage.trustedTargets.contains(target)) {
            revert Errors.TransactionValidationFailed(target);
        }

        result = target.functionCallWithValue(data, value);
    }

    /// @notice Execute a batch of calls
    /// @param calls The array of calls to execute
    function manageBatch(Call[] calldata calls) public payable virtual requiresAuth {
        require(calls.length > 0, "No calls provided");

        for (uint256 i = 0; i < calls.length; ++i) {
            bytes memory result = _manage(calls[i].target, calls[i].data, calls[i].value);
            emit ManageBatchOperation(i, calls[i].target, bytes4(calls[i].data), calls[i].value, result);
        }
    }

    /// @notice Sweep ERC20 token from the vault
    /// @param token The token to sweep
    function sweepToken(address token) public virtual requiresAuth {
        require(token != address(0), "Invalid token");
        IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    /// @notice Sweep ETH from the vault
    function sweepETH() public virtual requiresAuth {
        payable(owner()).transfer(address(this).balance);
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal virtual override requiresAuth {
        newImplementation;
    }
}
