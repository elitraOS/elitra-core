// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFeeRegistry } from "../../src/interfaces/IFeeRegistry.sol";

/**
 * @title FeeRegistryMock
 * @notice Mock implementation of IFeeRegistry for testing.
 */
contract FeeRegistryMock is IFeeRegistry {
    uint16 public protocolFeeRateBpsGlobal;
    address public override protocolFeeReceiver;
    mapping(address vault => uint16 rateBps) public protocolFeeRateBpsByVault;
    mapping(address vault => bool enabled) public hasCustomProtocolRate;

    constructor(uint16 _protocolFeeRateBps, address _protocolFeeReceiver) {
        protocolFeeRateBpsGlobal = _protocolFeeRateBps;
        protocolFeeReceiver = _protocolFeeReceiver;
    }

    function setProtocolFeeRateBps(uint16 _protocolFeeRateBps) external {
        protocolFeeRateBpsGlobal = _protocolFeeRateBps;
    }

    function setProtocolFeeRateBpsForVault(address vault, uint16 _protocolFeeRateBps) external {
        protocolFeeRateBpsByVault[vault] = _protocolFeeRateBps;
        hasCustomProtocolRate[vault] = true;
    }

    function clearProtocolFeeRateBpsForVault(address vault) external {
        delete protocolFeeRateBpsByVault[vault];
        delete hasCustomProtocolRate[vault];
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

    function setProtocolFeeReceiver(address _protocolFeeReceiver) external {
        protocolFeeReceiver = _protocolFeeReceiver;
    }
}
