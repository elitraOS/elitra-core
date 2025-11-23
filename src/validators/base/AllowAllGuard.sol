// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/// @title AllowAllGuard
/// @author Elitra
/// @notice A pass-through guard that approves all calls without restriction.
/// @dev Use strictly for trusted targets (e.g. WETH wrapping) where parameter validation is unnecessary.
///      Applying this to complex protocols (like DEXs) negates security checks.
contract AllowAllGuard is ITransactionGuard {
    /// @inheritdoc ITransactionGuard
    function validate(address, bytes calldata, uint256) external pure override returns (bool) {
        return true;
    }
}

