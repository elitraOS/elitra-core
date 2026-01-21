// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/// @title TakaraPoolGuard
/// @author Elitra
/// @notice Guard for Takara lending pool operations (mint/redeem).
/// @dev Only allows mint and redeem function calls.
contract TakaraPoolGuard is ITransactionGuard {
    /// @notice mint(uint256) selector
    bytes4 public constant MINT_SELECTOR = 0xa0712d68;

    /// @notice redeem(uint256) selector
    bytes4 public constant REDEEM_SELECTOR = 0xdb006a75;

    /// @inheritdoc ITransactionGuard
    function validate(address, bytes calldata data, uint256) external pure override returns (bool) {
        bytes4 sig = bytes4(data);

        // Only allow mint and redeem operations
        // mint(uint256 mintAmount) - deposit underlying to get cTokens
        // redeem(uint256 redeemAmount) - redeem cTokens for underlying
        if (sig == MINT_SELECTOR || sig == REDEEM_SELECTOR) {
            return true;
        }

        return false;
    }
}
