// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TakaraComptrollerGuard
/// @author Elitra
/// @notice Guard for Takara Comptroller reward claiming operations.
/// @dev Only allows claimReward function calls.
contract TakaraControllerGuard is ITransactionGuard, Ownable {
    /// @notice claimReward() selector
    bytes4 public constant CLAIM_REWARD_SELECTOR = 0xb88a802f;

    /// @notice Initializes the guard with the owner
    /// @param _owner The address of the owner
    constructor(address _owner) {
        _transferOwnership(_owner);
    }

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
