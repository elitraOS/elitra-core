// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IFeeRegistry } from "../interfaces/IFeeRegistry.sol";

/**
 * @title FeeRegistry
 * @author Elitra
 * @notice Protocol-controlled fee registry shared by vaults for managing protocol-level fee rates
 * @dev Stores global and per-vault protocol fee rates, with a maximum cap of 30%
 */
contract FeeRegistry is Ownable, IFeeRegistry {
    /// @notice Maximum protocol fee rate (30% in basis points)
    uint16 public constant MAX_PROTOCOL_RATE = 3000; // 30%

    struct RateSchedule {
        uint16 currentRateBps;
        uint16 pendingRateBps;
        uint256 applyTimestamp; // 0 = no pending update
    }

    /// @notice Global protocol fee rate schedule
    RateSchedule internal _globalSchedule;

    /// @notice Per-vault custom protocol fee rate schedules
    mapping(address vault => RateSchedule) internal _vaultSchedules;

    /// @notice Whether a vault has a custom protocol rate (true = use vault schedule, false = use global)
    mapping(address vault => bool) public hasCustomProtocolRate;

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
        hasCustomProtocolRate[vault] = true;
        _syncAndGetCurrent(_vaultSchedules[vault]);
        _scheduleRate(_vaultSchedules[vault], newRateBps);
        emit ProtocolFeeRateForVaultUpdated(vault, oldRate, newRateBps);
    }

    /// @notice Removes a custom protocol fee rate for a vault, reverting to global rate (immediate)
    /// @param vault Address of the vault to clear the custom rate from
    function clearProtocolFeeRateBpsForVault(address vault) external onlyOwner {
        require(vault != address(0), "vault zero");
        uint16 oldRate = _effectiveRateForVault(vault);
        delete _vaultSchedules[vault];
        delete hasCustomProtocolRate[vault];
        emit ProtocolFeeRateForVaultUpdated(vault, oldRate, 0);
    }

    // ========================================= RATE GETTERS =========================================

    /// @notice Gets the effective protocol fee rate for a specific vault
    /// @param vault Address of the vault to query
    /// @return The fee rate in basis points (custom rate if set, otherwise global rate)
    function protocolFeeRateBps(address vault) external view returns (uint16) {
        return _effectiveRateForVault(vault);
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

    /// @dev Resolves the effective rate from a schedule (respects cooldown)
    function _effectiveRate(RateSchedule storage schedule) internal view returns (uint16) {
        if (schedule.applyTimestamp != 0 && block.timestamp >= schedule.applyTimestamp) {
            return schedule.pendingRateBps;
        }
        return schedule.currentRateBps;
    }

    /// @dev Resolves the effective rate for a vault (custom if set, otherwise global)
    function _effectiveRateForVault(address vault) internal view returns (uint16) {
        if (hasCustomProtocolRate[vault]) {
            return _effectiveRate(_vaultSchedules[vault]);
        }
        return _effectiveRate(_globalSchedule);
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
