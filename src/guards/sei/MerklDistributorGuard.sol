// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/// @title MerklDistributorGuard
/// @author Elitra
/// @notice Guard for Merkl distributor claim operations.
/// @dev Restricts claims to this vault address.
contract MerklDistributorGuard is ITransactionGuard {
    /// @notice claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs) selector
    bytes4 public constant CLAIM_SELECTOR = 0x71ee95c0;

    /// @notice Vault address that must appear in the `users` list
    address public immutable vault;

    /// @notice Initializes the guard with the vault
    /// @param _vault The vault address that must be present in claim users
    constructor(address _vault) {
        vault = _vault;
    }

    /// @inheritdoc ITransactionGuard
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        bytes4 sig = bytes4(data);
        if (sig != CLAIM_SELECTOR) return false;

        (address[] memory users, address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs) =
            abi.decode(data[4:], (address[], address[], uint256[], bytes32[][]));

        uint256 n = users.length;
        if (n == 0 || tokens.length != n || amounts.length != n || proofs.length != n) return false;

        for (uint256 i = 0; i < n; ++i) {
            // Claims must be for this vault only
            if (users[i] != vault) return false;
            tokens[i];
            amounts[i];
            proofs[i];
        }

        return true;
    }
}


