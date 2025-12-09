// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
 * @title ITokenMessengerV2
 * @notice Interface for Circle CCTP V2 TokenMessenger
 * @dev Based on https://github.com/circlefin/evm-cctp-contracts
 */
interface ITokenMessengerV2 {
    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain to receive message on
     * @param mintRecipient address of mint recipient on destination domain
     * @param burnToken token to burn `amount` of, on local domain
     * @param destinationCaller authorized caller on the destination domain, as bytes32.
     *        If equal to bytes32(0), any address can broadcast the message.
     * @param maxFee maximum fee to pay on the destination domain, specified in units of burnToken
     * @param minFinalityThreshold the minimum finality at which a burn message will be attested to.
     *        1000 = fast (confirmed), 2000 = standard (finalized)
     */
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external;

    /**
     * @notice Deposits and burns tokens with hook data for execution on destination domain.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain to receive message on
     * @param mintRecipient address of mint recipient on destination domain, as bytes32
     * @param burnToken token to burn `amount` of, on local domain
     * @param destinationCaller authorized caller on the destination domain, as bytes32.
     * @param maxFee maximum fee to pay on the destination domain, specified in units of burnToken
     * @param minFinalityThreshold the minimum finality at which a burn message will be attested to.
     * @param hookData hook data to append to burn message for interpretation on destination domain
     */
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external;

    /**
     * @notice Returns the minimum fee for a given amount
     * @param amount The amount for which to calculate the minimum fee
     * @return The minimum fee for the given amount
     */
    function getMinFeeAmount(uint256 amount) external view returns (uint256);
}
