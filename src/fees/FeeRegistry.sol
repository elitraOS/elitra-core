// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IFeeRegistry } from "../interfaces/IFeeRegistry.sol";

/**
 * @title Fee Registry
 * @author Elitra
 * @notice Protocol-controlled fee registry shared by vaults for managing protocol-level fee rates
 * @dev Stores global and per-vault protocol fee rates, with a maximum cap of 30%
 */
contract FeeRegistry is Ownable, IFeeRegistry {
    /// @notice Maximum protocol fee rate (30% in basis points)
    uint16 public constant MAX_PROTOCOL_RATE = 3000; // 30%

    /// @notice Vault rate state tracks whether a vault uses global rate, custom rate, or is pending clear
    enum VaultRateState { None, Active, PendingClear }

    struct RateSchedule {
        uint16 currentRateBps;
        uint16 pendingRateBps;
        uint256 applyTimestamp; // 0 = no pending update
    }

    /// @notice Global protocol fee rate schedule
    RateSchedule internal _globalSchedule;

    /// @notice Per-vault custom protocol fee rate schedules
    mapping(address vault => RateSchedule) internal _vaultSchedules;

    /// @notice State of each vault's rate configuration
    mapping(address vault => VaultRateState) public vaultRateState;

    /// @notice Per-vault timestamp when pending clear becomes effective (only used when state = PendingClear)
    mapping(address vault => uint256) public vaultClearTimestamp;

    /// @notice Cooldown before protocol fee rate changes become effective (0 = immediate)
    uint256 public protocolFeeRateCooldown;

    /// @notice Address where protocol fees are sent
    address public protocolFeeReceiver;

    event ProtocolFeeRateUpdated(uint16 oldRateBps, uint16 newRateBps);
    event ProtocolFeeRateForVaultUpdated(address indexed vault, uint16 oldRateBps, uint16 newRateBps);
    event ProtocolFeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);
    event ProtocolFeeRateCooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    constructor(address initialOwner, address initialProtocolReceiver) {
        require(initialProtocolReceiver != address(0), "receiver zero");
        _transferOwnership(initialOwner);
        protocolFeeReceiver = initialProtocolReceiver;
    }

    // ========================================= RATE SETTERS =========================================

    /// @notice Sets the global protocol fee rate for all vaults without custom rates
    /// @param newRateBps New fee rate in basis points (max 3000 = 30%)
    function setProtocolFeeRateBps(uint16 newRateBps) external onlyOwner {
        require(newRateBps <= MAX_PROTOCOL_RATE, "rate too high");
        uint16 oldRate = _syncAndGetCurrent(_globalSchedule);
        _scheduleRate(_globalSchedule, newRateBps);
        emit ProtocolFeeRateUpdated(oldRate, newRateBps);
    }

    /// @notice Sets a custom protocol fee rate for a specific vault
    /// @param vault Address of the vault to set the custom rate for
    /// @param newRateBps New fee rate in basis points (max 3000 = 30%)
    function setProtocolFeeRateBpsForVault(address vault, uint16 newRateBps) external onlyOwner {
        require(vault != address(0), "vault zero");
        require(newRateBps <= MAX_PROTOCOL_RATE, "rate too high");
        uint16 oldRate = _effectiveRateForVault(vault);

        // If transitioning from global to custom, initialize currentRateBps to current global rate
        // This prevents the rate from dropping to 0 during the cooldown period
        bool wasUsingGlobal = vaultRateState[vault] == VaultRateState.None;
        vaultRateState[vault] = VaultRateState.Active;

        if (wasUsingGlobal) {
            _vaultSchedules[vault].currentRateBps = _effectiveRate(_globalSchedule);
        }

        _syncAndGetCurrent(_vaultSchedules[vault]);
        _scheduleRate(_vaultSchedules[vault], newRateBps);
        emit ProtocolFeeRateForVaultUpdated(vault, oldRate, newRateBps);
    }

    /// @notice Removes a custom protocol fee rate for a vault, reverting to global rate
    /// @param vault Address of the vault to clear the custom rate from
    function clearProtocolFeeRateBpsForVault(address vault) external onlyOwner {
        require(vault != address(0), "vault zero");
        require(vaultRateState[vault] == VaultRateState.Active, "no custom rate");

        uint16 oldRate = _effectiveRateForVault(vault);

        if (protocolFeeRateCooldown == 0) {
            _clearVaultRate(vault, oldRate);
        } else {
            // Schedule the clear operation to respect cooldown
            vaultRateState[vault] = VaultRateState.PendingClear;
            vaultClearTimestamp[vault] = block.timestamp + protocolFeeRateCooldown;
            emit ProtocolFeeRateForVaultUpdated(vault, oldRate, 0);
        }
    }

    // ========================================= RATE GETTERS =========================================

    /// @notice Syncs a vault's state (executes pending clears if cooldown has elapsed)
    /// @param vault Address of the vault to sync
    function syncVault(address vault) external {
        _effectiveRateForVault(vault);
    }

    /// @notice Gets the effective protocol fee rate for a specific vault
    /// @param vault Address of the vault to query
    /// @return The fee rate in basis points (custom rate if set, otherwise global rate)
    function protocolFeeRateBps(address vault) external view returns (uint16) {
        return _effectiveRateForVaultView(vault);
    }

    /// @notice Gets the effective global protocol fee rate
    /// @return The global fee rate in basis points
    function protocolFeeRateBps() external view returns (uint16) {
        return _effectiveRate(_globalSchedule);
    }

    /// @notice Gets the active global protocol fee rate (without pending updates)
    function protocolFeeRateBpsGlobal() external view returns (uint16) {
        return _globalSchedule.currentRateBps;
    }

    /// @notice Gets the active per-vault custom protocol fee rate (without pending updates)
    function protocolFeeRateBpsByVault(address vault) external view returns (uint16) {
        return _vaultSchedules[vault].currentRateBps;
    }

    /// @notice Checks if a vault has a pending clear operation
    /// @param vault Address of the vault to query
    /// @return isPending True if a clear operation is pending
    /// @return applyTimestamp Timestamp when the clear will become effective (0 if not pending)
    function isProtocolRateClearPending(address vault) external view returns (bool, uint256) {
        if (vaultRateState[vault] != VaultRateState.PendingClear) return (false, 0);
        return (true, vaultClearTimestamp[vault]);
    }

    // ========================================= CONFIG =========================================

    /// @notice Sets the address where protocol fees are sent
    /// @param newReceiver New address to receive protocol fees
    function setProtocolFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "receiver zero");
        emit ProtocolFeeReceiverUpdated(protocolFeeReceiver, newReceiver);
        protocolFeeReceiver = newReceiver;
    }

    /// @notice Sets cooldown before protocol fee rate updates become active
    /// @param newCooldown Cooldown in seconds (0 = immediate updates)
    function setProtocolFeeRateCooldown(uint256 newCooldown) external onlyOwner {
        emit ProtocolFeeRateCooldownUpdated(protocolFeeRateCooldown, newCooldown);
        protocolFeeRateCooldown = newCooldown;
    }

    // ========================================= INTERNAL =========================================

    /// @dev Clears a vault's custom rate, reverting to global rate
    function _clearVaultRate(address vault, uint16 oldRate) internal {
        delete _vaultSchedules[vault];
        delete vaultClearTimestamp[vault];
        vaultRateState[vault] = VaultRateState.None;
        emit ProtocolFeeRateForVaultUpdated(vault, oldRate, 0);
    }

    /// @dev Resolves the effective rate for a vault (custom if set, otherwise global)
    function _effectiveRateForVault(address vault) internal returns (uint16) {
        VaultRateState state = vaultRateState[vault];

        // Handle pending clear operation
        if (state == VaultRateState.PendingClear) {
            if (block.timestamp >= vaultClearTimestamp[vault]) {
                uint16 oldRate = _effectiveRate(_vaultSchedules[vault]);
                _clearVaultRate(vault, oldRate);
                return _effectiveRate(_globalSchedule);
            }
            // Still in cooldown, return current vault rate
            return _effectiveRate(_vaultSchedules[vault]);
        }

        // Active custom rate
        if (state == VaultRateState.Active) {
            return _effectiveRate(_vaultSchedules[vault]);
        }

        // No custom rate, use global
        return _effectiveRate(_globalSchedule);
    }

    /// @dev View-only version of _effectiveRateForVault (does not execute pending clears)
    function _effectiveRateForVaultView(address vault) internal view returns (uint16) {
        VaultRateState state = vaultRateState[vault];

        // Handle pending clear operation (view version)
        if (state == VaultRateState.PendingClear) {
            if (block.timestamp >= vaultClearTimestamp[vault]) {
                return _effectiveRate(_globalSchedule);
            }
            return _effectiveRate(_vaultSchedules[vault]);
        }

        // Active custom rate
        if (state == VaultRateState.Active) {
            return _effectiveRate(_vaultSchedules[vault]);
        }

        // No custom rate, use global
        return _effectiveRate(_globalSchedule);
    }

    /// @dev Resolves the effective rate from a schedule (respects cooldown)
    function _effectiveRate(RateSchedule storage schedule) internal view returns (uint16) {
        if (schedule.applyTimestamp != 0 && block.timestamp >= schedule.applyTimestamp) {
            return schedule.pendingRateBps;
        }
        return schedule.currentRateBps;
    }

    /// @dev Syncs a matured pending rate into current and returns the current rate
    function _syncAndGetCurrent(RateSchedule storage schedule) internal returns (uint16) {
        if (schedule.applyTimestamp != 0 && block.timestamp >= schedule.applyTimestamp) {
            schedule.currentRateBps = schedule.pendingRateBps;
            schedule.pendingRateBps = 0;
            schedule.applyTimestamp = 0;
        }
        return schedule.currentRateBps;
    }

    /// @dev Schedules a new rate (immediate if no cooldown, delayed otherwise)
    function _scheduleRate(RateSchedule storage schedule, uint16 newRateBps) internal {
        if (protocolFeeRateCooldown == 0) {
            schedule.currentRateBps = newRateBps;
            schedule.pendingRateBps = 0;
            schedule.applyTimestamp = 0;
        } else {
            schedule.pendingRateBps = newRateBps;
            schedule.applyTimestamp = block.timestamp + protocolFeeRateCooldown;
        }
    }
}
