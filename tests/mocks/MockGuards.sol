// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../src/interfaces/ITransactionGuard.sol";

/// @notice Mock guard that allows all transactions
contract AllowAllGuard is ITransactionGuard {
    function validate(address, bytes calldata, uint256) external pure override returns (bool) {
        return true;
    }
}

/// @notice Mock guard that blocks all transactions
contract BlockAllGuard is ITransactionGuard {
    function validate(address, bytes calldata, uint256) external pure override returns (bool) {
        return false;
    }
}
