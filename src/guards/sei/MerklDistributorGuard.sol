// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/**
 * @title MerklDistributorGuard
 * @author Elitra
 * @notice Guard for Merkl distributor claim operations
 * @dev Restricts claims to ensure rewards are only claimed for the protected vault address
 *
 * @dev Merkl is a reward distribution protocol. This guard ensures that when claiming rewards,
 *      all user addresses in the claim must be the vault address. This prevents claiming rewards
 *      for other users' addresses.
 */
contract MerklDistributorGuard is ITransactionGuard {
    /// @notice Function selector for claim(address[],address[],uint256[],bytes32[][]): 0x71ee95c0
    bytes4 public constant CLAIM_SELECTOR = 0x71ee95c0;

    /// @notice The vault address that must be the only recipient in claims
    address public immutable vault;

    /**
     * @notice Initializes the guard with the vault address to protect
     * @param _vault The vault address that must be the only user in claim operations
     */
    constructor(address _vault) {
        vault = _vault;
    }

    /**
     * @notice Validates a transaction against the guard's rules
     * @inheritdoc ITransactionGuard
     * @dev Only allows claim() calls where all users in the array are the vault address
     * @return True if the claim is valid (only for the vault), false otherwise
     */
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 sig = bytes4(data);
        if (sig != CLAIM_SELECTOR) return false;

        // Decode the claim parameters
        (address[] memory users, address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs) =
            abi.decode(data[4:], (address[], address[], uint256[], bytes32[][]));

        uint256 n = users.length;
        // Validate array lengths match
        if (n == 0 || tokens.length != n || amounts.length != n || proofs.length != n) return false;

        // Ensure all users are the vault address (claims only for this vault)
        for (uint256 i = 0; i < n; ++i) {
            if (users[i] != vault) return false;
            // tokens[i], amounts[i], and proofs[i] are validated by Merkl contract
            tokens[i];
            amounts[i];
            proofs[i];
        }

        return true;
    }
}
