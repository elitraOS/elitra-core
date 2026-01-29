// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IFeeRegistry } from "../interfaces/IFeeRegistry.sol";

/// @notice Protocol-controlled fee registry shared by vaults.
contract FeeRegistry is Ownable, IFeeRegistry {
    uint16 public constant MAX_PROTOCOL_RATE = 3000; // 30%

    uint16 public protocolFeeRateBpsGlobal;
    address public protocolFeeReceiver;
    mapping(address vault => uint16 rateBps) public protocolFeeRateBpsByVault;
    mapping(address vault => bool enabled) public hasCustomProtocolRate;

    event ProtocolFeeRateUpdated(uint16 oldRateBps, uint16 newRateBps);
    event ProtocolFeeRateForVaultUpdated(address indexed vault, uint16 oldRateBps, uint16 newRateBps);
    event ProtocolFeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);

    constructor(address initialOwner, address initialProtocolReceiver) {
        require(initialProtocolReceiver != address(0), "receiver zero");
        _transferOwnership(initialOwner);
        protocolFeeReceiver = initialProtocolReceiver;
    }

    function setProtocolFeeRateBps(uint16 newRateBps) external onlyOwner {
        require(newRateBps <= MAX_PROTOCOL_RATE, "rate too high");
        emit ProtocolFeeRateUpdated(protocolFeeRateBpsGlobal, newRateBps);
        protocolFeeRateBpsGlobal = newRateBps;
    }

    function setProtocolFeeRateBpsForVault(address vault, uint16 newRateBps) external onlyOwner {
        require(vault != address(0), "vault zero");
        require(newRateBps <= MAX_PROTOCOL_RATE, "rate too high");
        uint16 oldRate = protocolFeeRateBpsByVault[vault];
        protocolFeeRateBpsByVault[vault] = newRateBps;
        hasCustomProtocolRate[vault] = true;
        emit ProtocolFeeRateForVaultUpdated(vault, oldRate, newRateBps);
    }

    function clearProtocolFeeRateBpsForVault(address vault) external onlyOwner {
        require(vault != address(0), "vault zero");
        uint16 oldRate = protocolFeeRateBpsByVault[vault];
        delete protocolFeeRateBpsByVault[vault];
        delete hasCustomProtocolRate[vault];
        emit ProtocolFeeRateForVaultUpdated(vault, oldRate, 0);
    }

    function protocolFeeRateBps(address vault) external view returns (uint16) {
        if (hasCustomProtocolRate[vault]) {
            return protocolFeeRateBpsByVault[vault];
        }
        return protocolFeeRateBpsGlobal;
    }

    function protocolFeeRateBps() external view returns (uint16) {
        return protocolFeeRateBpsGlobal;
    }

    function setProtocolFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "receiver zero");
        emit ProtocolFeeReceiverUpdated(protocolFeeReceiver, newReceiver);
        protocolFeeReceiver = newReceiver;
    }
}
