// SPDX-License-Identifier: UNLICENSED
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

/// @notice Mock transaction guard for testing
contract MockTransactionGuard is ITransactionGuard {
    bool public shouldValidate = true;

    function validate(address, bytes calldata, uint256) external view override returns (bool) {
        return shouldValidate;
    }

    function setShouldValidate(bool value) external {
        shouldValidate = value;
    }
}
