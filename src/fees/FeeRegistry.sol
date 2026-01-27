// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IFeeRegistry } from "../interfaces/IFeeRegistry.sol";

/// @notice Protocol-controlled fee registry shared by vaults.
contract FeeRegistry is Ownable, IFeeRegistry {
    uint16 public constant MAX_PROTOCOL_RATE = 3000; // 30%

    uint16 public protocolFeeRateBps;
    address public protocolFeeReceiver;

    event ProtocolFeeRateUpdated(uint16 oldRateBps, uint16 newRateBps);
    event ProtocolFeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);

    constructor(address initialOwner, address initialProtocolReceiver) {
        require(initialProtocolReceiver != address(0), "receiver zero");
        _transferOwnership(initialOwner);
        protocolFeeReceiver = initialProtocolReceiver;
    }

    function setProtocolFeeRateBps(uint16 newRateBps) external onlyOwner {
        require(newRateBps <= MAX_PROTOCOL_RATE, "rate too high");
        emit ProtocolFeeRateUpdated(protocolFeeRateBps, newRateBps);
        protocolFeeRateBps = newRateBps;
    }

    function setProtocolFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "receiver zero");
        emit ProtocolFeeReceiverUpdated(protocolFeeReceiver, newReceiver);
        protocolFeeReceiver = newReceiver;
    }
}
