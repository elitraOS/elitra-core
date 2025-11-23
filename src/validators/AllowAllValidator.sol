// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ICallValidator } from "../interfaces/ICallValidator.sol";

/// @title AllowAllValidator
/// @author Elitra
/// @notice A pass-through validator that approves all calls without restriction.
/// @dev Use strictly for trusted targets (e.g. WETH wrapping) where parameter validation is unnecessary.
///      Applying this to complex protocols (like DEXs) negates security checks.
contract AllowAllValidator is ICallValidator {
    /// @inheritdoc ICallValidator
    function validate(address, bytes calldata, uint256) external pure override returns (bool) {
        return true;
    }
}

