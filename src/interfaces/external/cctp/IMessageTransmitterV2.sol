// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
 * @title IMessageTransmitterV2
 * @notice Interface for Circle CCTP V2 MessageTransmitter
 * @dev Based on https://github.com/circlefin/evm-cctp-contracts
 */
interface IMessageTransmitterV2 {
    /**
     * @notice Receives a message and its attestation, validates, and relays to destination handler
     * @param message The message bytes
     * @param attestation The attestation signature bytes
     * @return success True if the message was successfully received
     */
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool success);

    /**
     * @notice Returns the local domain identifier
     * @return The local domain
     */
    function localDomain() external view returns (uint32);

    /**
     * @notice Returns the next available nonce for the given source domain
     * @return The next nonce
     */
    function nextAvailableNonce() external view returns (uint64);

    /**
     * @notice Checks if a nonce has been used for a given source domain
     * @param sourceDomain The source domain
     * @param nonce The nonce to check
     * @return True if the nonce has been used
     */
    function usedNonces(uint32 sourceDomain, bytes32 nonce) external view returns (bool);
}
