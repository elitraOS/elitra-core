// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";

/// @title ApproveGuard
/// @author Elitra
/// @notice Generic guard for ERC20 approval operations.
/// @dev Restricts approvals to specific whitelisted spenders.
contract ApproveGuard is ITransactionGuard {
    
    /// @notice approve(address,uint256) selector: 0x095ea7b3
    bytes4 public constant APPROVE_SELECTOR = 0x095ea7b3;

    /// @notice Mapping of allowed spender addresses
    mapping(address spender => bool isAllowed) public whitelistedSpenders;

    /// @notice Initializes the guard with a list of whitelisted spenders
    /// @param _spenders The list of addresses allowed to spend tokens
    constructor(address[] memory _spenders) {
        for (uint256 i = 0; i < _spenders.length; ++i) {
            whitelistedSpenders[_spenders[i]] = true;
        }
    }

    /// @inheritdoc ITransactionGuard
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        bytes4 sig = bytes4(data);
        
        if (sig == APPROVE_SELECTOR) {
            // Decode the spender from calldata (first argument)
            // calldata layout: [4 bytes selector][32 bytes spender][32 bytes amount]
            address spender = abi.decode(data[4:36], (address));
            
            return whitelistedSpenders[spender];
        }

        return false;
    }
}

