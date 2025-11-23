// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/// @title NativeWrapGuard
/// @author Elitra
/// @notice Guard for Native Token (WETH) wrapping/unwrapping operations.
/// @dev Only allows deposit() and withdraw() functions.
contract NativeWrapGuard is ITransactionGuard {
    
    /// @notice deposit() selector: 0xd0e30db0
    bytes4 public constant DEPOSIT_SELECTOR = 0xd0e30db0;
    
    /// @notice withdraw(uint256) selector: 0x2e1a7d4d
    bytes4 public constant WITHDRAW_SELECTOR = 0x2e1a7d4d;

    /// @inheritdoc ITransactionGuard
    function validate(address, bytes calldata data, uint256) external pure override returns (bool) {
        bytes4 sig = bytes4(data);
        
        // Allow deposit() - Wrapping ETH to WETH
        if (sig == DEPOSIT_SELECTOR) {
            return true;
        }
        
        // Allow withdraw(uint256) - Unwrapping WETH to ETH
        if (sig == WITHDRAW_SELECTOR) {
            return true;
        }

        return false;
    }
}

