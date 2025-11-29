// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title WNativeGuard
/// @author Elitra
/// @notice Guard for wrapped native token operations (WSEI, WETH, etc.).
/// @dev Allows approve (whitelisted spenders), deposit (wrap), and withdraw (unwrap) operations.
contract WNativeGuard is ITransactionGuard, Ownable {
    /// @notice approve(address,uint256) selector: 0x095ea7b3
    bytes4 public constant APPROVE_SELECTOR = 0x095ea7b3;

    /// @notice deposit() selector: 0xd0e30db0 (for wrapping native token)
    bytes4 public constant DEPOSIT_SELECTOR = 0xd0e30db0;

    /// @notice withdraw(uint256) selector: 0x2e1a7d4d (for unwrapping to native token)
    bytes4 public constant WITHDRAW_SELECTOR = 0x2e1a7d4d;

    /// @notice Mapping of allowed spender addresses
    mapping(address spender => bool isAllowed) public whitelistedSpenders;

    constructor(address _owner) {
        _transferOwnership(_owner);
    }

    function setSpender(address _spender, bool _isAllowed) external onlyOwner {
        whitelistedSpenders[_spender] = _isAllowed;
    }

    /// @inheritdoc ITransactionGuard
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        bytes4 sig = bytes4(data);

        if (sig == APPROVE_SELECTOR) {
            address spender = abi.decode(data[4:36], (address));
            return whitelistedSpenders[spender];
        }

        return sig == DEPOSIT_SELECTOR || sig == WITHDRAW_SELECTOR;
    }
}
