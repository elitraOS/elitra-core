// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { ITransactionGuard } from "../../interfaces/ITransactionGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenGuard
 * @author Elitra
 * @notice Generic guard for ERC20 token approval operations
 * @dev Restricts approvals to specific whitelisted spender addresses for security
 *
 * @dev This guard is useful when a vault needs to approve specific contracts (like DEXs or lending protocols)
 *      but wants to prevent approval to arbitrary addresses. Only pre-approved spenders can receive approvals.
 */
contract TokenGuard is ITransactionGuard, Ownable {
    /// @notice Function selector for approve(address,uint256): 0x095ea7b3
    bytes4 public constant APPROVE_SELECTOR = 0x095ea7b3;

    /// @notice Maps spender addresses to their whitelist status
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
     * @dev Only allows approve() calls to whitelisted spenders
     * @return True if the transaction is allowed, false otherwise
     */
    function validate(address, bytes calldata data, uint256) external view override returns (bool) {
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 sig = bytes4(data);

        if (sig == APPROVE_SELECTOR) {
            // Decode the spender from calldata (first argument after selector)
            address spender = abi.decode(data[4:36], (address));
            return whitelistedSpenders[spender];
        }

        return false;
    }
}
