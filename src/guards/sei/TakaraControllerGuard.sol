// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/// @title TakaraComptrollerGuard
/// @author Elitra
/// @notice Guard for Takara Comptroller reward claiming operations.
/// @dev Only allows claimReward function calls.
contract TakaraControllerGuard is ITransactionGuard {
    /// @notice claimReward() selector
    bytes4 public constant CLAIM_REWARD_SELECTOR = 0xb88a802f;

    /// @inheritdoc ITransactionGuard
    function validate(address, bytes calldata data, uint256) external pure override returns (bool) {
        bytes4 sig = bytes4(data);

        // Only allow claimReward operation
        if (sig == CLAIM_REWARD_SELECTOR) {
            return true;
        }

        return false;
    }
}
