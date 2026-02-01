// SPDX-License-Identifier: MIT
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

    /// @notice Global protocol fee rate in basis points (applies to all vaults without custom rates)
    uint16 public protocolFeeRateBpsGlobal;

    /// @notice Address where protocol fees are sent
    address public protocolFeeReceiver;

    /// @notice Per-vault custom protocol fee rates (in basis points)
    mapping(address vault => uint16 rateBps) public protocolFeeRateBpsByVault;

    /// @notice Tracks whether a vault has a custom protocol fee rate set
    mapping(address vault => bool enabled) public hasCustomProtocolRate;

    /// @notice Emitted when the global protocol fee rate is updated
    event ProtocolFeeRateUpdated(uint16 oldRateBps, uint16 newRateBps);

    /// @notice Emitted when a vault's custom protocol fee rate is updated
    event ProtocolFeeRateForVaultUpdated(address indexed vault, uint16 oldRateBps, uint16 newRateBps);

    /// @notice Emitted when the protocol fee receiver address is changed
    event ProtocolFeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);

    /**
     * @notice Initializes the fee registry with owner and fee receiver
     * @param initialOwner Address that will own the contract (can set fee rates)
     * @param initialProtocolReceiver Address where protocol fees will be sent
     */
    constructor(address initialOwner, address initialProtocolReceiver) {
        require(initialProtocolReceiver != address(0), "receiver zero");
        _transferOwnership(initialOwner);
        protocolFeeReceiver = initialProtocolReceiver;
    }

    /**
     * @notice Sets the global protocol fee rate for all vaults without custom rates
     * @param newRateBps New fee rate in basis points (max 3000 = 30%)
     * @dev Vaults with custom rates set via `setProtocolFeeRateBpsForVault` are unaffected
     */
    function setProtocolFeeRateBps(uint16 newRateBps) external onlyOwner {
        require(newRateBps <= MAX_PROTOCOL_RATE, "rate too high");
        emit ProtocolFeeRateUpdated(protocolFeeRateBpsGlobal, newRateBps);
        protocolFeeRateBpsGlobal = newRateBps;
    }

    /**
     * @notice Sets a custom protocol fee rate for a specific vault
     * @param vault Address of the vault to set the custom rate for
     * @param newRateBps New fee rate in basis points (max 3000 = 30%)
     * @dev Custom rates override the global rate for the specified vault
     */
    function setProtocolFeeRateBpsForVault(address vault, uint16 newRateBps) external onlyOwner {
        require(vault != address(0), "vault zero");
        require(newRateBps <= MAX_PROTOCOL_RATE, "rate too high");
        uint16 oldRate = protocolFeeRateBpsByVault[vault];
        protocolFeeRateBpsByVault[vault] = newRateBps;
        hasCustomProtocolRate[vault] = true;
        emit ProtocolFeeRateForVaultUpdated(vault, oldRate, newRateBps);
    }

    /**
     * @notice Removes a custom protocol fee rate for a vault, reverting to global rate
     * @param vault Address of the vault to clear the custom rate from
     */
    function clearProtocolFeeRateBpsForVault(address vault) external onlyOwner {
        require(vault != address(0), "vault zero");
        uint16 oldRate = protocolFeeRateBpsByVault[vault];
        delete protocolFeeRateBpsByVault[vault];
        delete hasCustomProtocolRate[vault];
        emit ProtocolFeeRateForVaultUpdated(vault, oldRate, 0);
    }

    /**
     * @notice Gets the protocol fee rate for a specific vault
     * @param vault Address of the vault to query
     * @return The fee rate in basis points (custom rate if set, otherwise global rate)
     */
    function protocolFeeRateBps(address vault) external view returns (uint16) {
        if (hasCustomProtocolRate[vault]) {
            return protocolFeeRateBpsByVault[vault];
        }
        return protocolFeeRateBpsGlobal;
    }

    /**
     * @notice Gets the global protocol fee rate
     * @return The global fee rate in basis points
     */
    function protocolFeeRateBps() external view returns (uint16) {
        return protocolFeeRateBpsGlobal;
    }

    /**
     * @notice Sets the address where protocol fees are sent
     * @param newReceiver New address to receive protocol fees
     */
    function setProtocolFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "receiver zero");
        emit ProtocolFeeReceiverUpdated(protocolFeeReceiver, newReceiver);
        protocolFeeReceiver = newReceiver;
    }
}
