// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/**
 * @title MorphoVaultGuard
 * @author Elitra
 * @notice Guard for ERC4626/Morpho vault operations (deposit/withdraw)
 * @dev Restricts deposit receiver and withdraw receiver/owner to be the protected vault
 *
 * @dev Morpho is a lending protocol. This guard ensures that:
 *      - Deposits can only go to the vault (onBehalf parameter)
 *      - Withdrawals can only go to the vault (both receiver and owner)
 *      - This prevents depositing/withdrawing for other addresses
 */
contract MorphoVaultGuard is ITransactionGuard {
    /// @notice Function selector for deposit(uint256,address): 0x6e553f65
    bytes4 public constant DEPOSIT_SELECTOR = 0x6e553f65;

    /// @notice Function selector for withdraw(uint256,address,address): 0xb460af94
    bytes4 public constant WITHDRAW_SELECTOR = 0xb460af94;

    /// @notice The vault address that this guard protects
    address public immutable vault;

    /**
     * @notice Initializes the guard with the vault address to protect
     * @param _vault The vault address that must be the receiver/owner in all operations
     */
    constructor(address _vault) {
        vault = _vault;
    }

    /**
     * @notice Validates a transaction against the guard's rules
     * @inheritdoc ITransactionGuard
     * @dev Only allows deposit and withdraw where vault is the receiver/owner
     * @return True if the transaction is allowed (vault operations only), false otherwise
     */
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 sig = bytes4(data);

        if (sig == DEPOSIT_SELECTOR) {
            // deposit(uint256 assets, address onBehalf)
            // calldata: [4 selector][32 assets][32 onBehalf]
            (, address receiver) = abi.decode(data[4:], (uint256, address));

            // Receiver must be the vault (no depositing for other addresses)
            return receiver == vault;
        }

        if (sig == WITHDRAW_SELECTOR) {
            // withdraw(uint256 assets, address receiver, address owner)
            // calldata: [4 selector][32 assets][32 receiver][32 owner]
            (, address receiver, address owner) = abi.decode(data[4:], (uint256, address, address));

            // Both receiver and owner must be the vault (no withdrawing for other addresses)
            return receiver == vault && owner == vault;
        }

        return false;
    }
}
