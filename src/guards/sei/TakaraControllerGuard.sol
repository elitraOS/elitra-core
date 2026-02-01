// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/**
 * @title TakaraControllerGuard
 * @author Elitra
 * @notice Guard for Takara Comptroller reward claiming operations
 * @dev Only allows the claimReward function to be called
 *
 * @dev Takara is a lending protocol on SEI. The Comptroller handles reward distribution.
 *      This guard ensures that only the claimReward function can be called, preventing
 *      unauthorized operations like claiming for other users or modifying protocol settings.
 */
contract TakaraControllerGuard is ITransactionGuard {
    /// @notice Function selector for claimReward(): 0xb88a802f
    bytes4 public constant CLAIM_REWARD_SELECTOR = 0xb88a802f;

    /**
     * @notice Validates a transaction against the guard's rules
     * @inheritdoc ITransactionGuard
     * @dev Only allows claimReward() calls, all other functions are blocked
     * @return True if calling claimReward, false otherwise
     */
    function validate(address, bytes calldata data, uint256) external pure override returns (bool) {
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 sig = bytes4(data);

        // Only allow claimReward operation
        return sig == CLAIM_REWARD_SELECTOR;
    }
}
