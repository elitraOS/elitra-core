// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/// @title MorphoVaultGuard
/// @author Elitra
/// @notice Guard for ERC4626/Morpho vault operations (deposit/withdraw).
/// @dev Restricts deposit receiver and withdraw receiver/owner to be the vault.
contract MorphoVaultGuard is ITransactionGuard {
    /// @notice deposit(uint256,address) selector
    bytes4 public constant DEPOSIT_SELECTOR = 0x6e553f65;

    /// @notice withdraw(uint256,address,address) selector
    bytes4 public constant WITHDRAW_SELECTOR = 0xb460af94;

    /// @notice The vault address that this guard protects
    address public immutable vault;

    /// @notice Initializes the guard with the vault
    /// @param _vault The vault address that must be the receiver/owner
    constructor(address _vault) {
        vault = _vault;
    }

    /// @inheritdoc ITransactionGuard
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        bytes4 sig = bytes4(data);

        if (sig == DEPOSIT_SELECTOR) {
            // deposit(uint256 assets, address onBehalf)
            // calldata: [4 selector][32 assets][32 receiver]
            (, address receiver) = abi.decode(data[4:], (uint256, address));

            // Receiver must be the vault
            return receiver == vault;
        }

        if (sig == WITHDRAW_SELECTOR) {
            // withdraw(uint256 assets, address receiver, address onBehalf)
            // calldata: [4 selector][32 assets][32 receiver][32 owner]
            (, address receiver, address owner) = abi.decode(data[4:], (uint256, address, address));

            // Both receiver and owner must be the vault
            return receiver == vault && owner == vault;
        }

        return false;
    }
}
