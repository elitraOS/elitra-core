// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WNativeGuard
 * @author Elitra
 * @notice Guard for wrapped native token operations (WSEI, WETH, etc.)
 * @dev Allows approve (whitelisted spenders), deposit (wrap), and withdraw (unwrap) operations
 *
 * @dev This guard enables vaults to:
 *      - Approve specific spenders to use wrapped native tokens (with whitelist)
 *      - Deposit native tokens to wrap them (e.g., SEI -> WSEI)
 *      - Withdraw wrapped tokens to unwrap them (e.g., WSEI -> SEI)
 */
contract WNativeGuard is ITransactionGuard, Ownable {
    /// @notice Function selector for approve(address,uint256): 0x095ea7b3
    bytes4 public constant APPROVE_SELECTOR = 0x095ea7b3;

    /// @notice Function selector for deposit(): 0xd0e30db0 (wraps native token)
    bytes4 public constant DEPOSIT_SELECTOR = 0xd0e30db0;

    /// @notice Function selector for withdraw(uint256): 0x2e1a7d4d (unwraps to native)
    bytes4 public constant WITHDRAW_SELECTOR = 0x2e1a7d4d;

    /// @notice Maps spender addresses to their whitelist status for approvals
    mapping(address spender => bool isAllowed) public whitelistedSpenders;

    /// @notice Emitted when a spender's whitelist status is changed
    event SpenderUpdated(address indexed spender, bool isAllowed);

    /**
     * @notice Initializes the guard with the owner
     * @param _owner Address that will own this guard and can manage the whitelist
     */
    constructor(address _owner) {
        _transferOwnership(_owner);
    }

    /**
     * @notice Sets the whitelist status for a spender address
     * @dev Only the owner can call this function
     * @param _spender Address to whitelist or remove from whitelist
     * @param _isAllowed True to allow approvals to this spender, false to disallow
     */
    function setSpender(address _spender, bool _isAllowed) external onlyOwner {
        whitelistedSpenders[_spender] = _isAllowed;
        emit SpenderUpdated(_spender, _isAllowed);
    }

    /**
     * @notice Validates a transaction against the guard's rules
     * @inheritdoc ITransactionGuard
     * @dev Allows deposit/withdraw, approve(spender, 0) for revocation, and non-zero approve only to whitelisted spenders
     * @return True if the transaction is allowed, false otherwise
     */
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 sig = bytes4(data);

        if (sig == APPROVE_SELECTOR) {
            // Always allow allowance revocation even if spender is no longer whitelisted.
            address spender = abi.decode(data[4:36], (address));
            uint256 amount = abi.decode(data[36:68], (uint256));
            return amount == 0 || whitelistedSpenders[spender];
        }

        // Always allow deposit and withdraw operations (wrapping/unwrapping)
        return sig == DEPOSIT_SELECTOR || sig == WITHDRAW_SELECTOR;
    }
}
