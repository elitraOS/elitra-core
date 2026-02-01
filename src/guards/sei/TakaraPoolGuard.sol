// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/**
 * @title TakaraPoolGuard
 * @author Elitra
 * @notice Guard for Takara lending pool operations (mint/redeem)
 * @dev Only allows mint and redeem function calls
 *
 * @dev Takara is a lending protocol on SEI. This guard ensures that only:
 *      - mint(uint256): Deposit underlying tokens to get cTokens
 *      - redeem(uint256): Redeem cTokens for underlying tokens
 *      are allowed, preventing other operations like borrowing or liquidation.
 */
contract TakaraPoolGuard is ITransactionGuard {
    /// @notice Function selector for mint(uint256): 0xa0712d68
    bytes4 public constant MINT_SELECTOR = 0xa0712d68;

    /// @notice Function selector for redeem(uint256): 0xdb006a75
    bytes4 public constant REDEEM_SELECTOR = 0xdb006a75;

    /**
     * @notice Validates a transaction against the guard's rules
     * @inheritdoc ITransactionGuard
     * @dev Only allows mint and redeem operations
     * @return True if calling mint or redeem, false otherwise
     */
    function validate(address, bytes calldata data, uint256) external pure override returns (bool) {
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 sig = bytes4(data);

        // Only allow mint and redeem operations
        // mint(uint256 mintAmount) - deposit underlying to get cTokens
        // redeem(uint256 redeemAmount) - redeem cTokens for underlying
        return sig == MINT_SELECTOR || sig == REDEEM_SELECTOR;
    }
}
