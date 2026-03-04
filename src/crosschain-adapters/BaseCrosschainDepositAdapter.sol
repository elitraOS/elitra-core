// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ICrosschainDepositAdapter } from "../interfaces/ICrosschainDepositAdapter.sol";
import { ICrosschainDepositQueue } from "../interfaces/ICrosschainDepositQueue.sol";
import { IElitraVault } from "../interfaces/IElitraVault.sol";
import { Call } from "../interfaces/IVaultBase.sol";
import { ZapExecutor } from "./ZapExecutor.sol";

/**
 * @title BaseCrosschainDepositAdapter
 * @notice Shared logic for cross-chain vault deposits
 */
abstract contract BaseCrosschainDepositAdapter is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ICrosschainDepositAdapter
{
    using SafeERC20 for IERC20;

    // Role allowed to pause/unpause and manage adapter ops.
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ================== STATE VARIABLES ==================
    
    // Monotonic deposit id counter.
    uint256 public totalDeposits;
    // DepositId => record for tracking.
    mapping(uint256 => DepositRecord) public depositRecords;
    // User => list of deposit ids for UI.
    mapping(address => uint256[]) public userDepositIds;
    // Allowlist of vaults that can receive cross-chain deposits.
    mapping(address => bool) public supportedVaults;

    // Optional queue for failed deposits.
    address public depositQueue;
    // Optional zap executor for swap + deposit flows.
    ZapExecutor public zapExecutor;
    // Native refunds that could not be pushed to users.
    mapping(address => uint256) public pendingNativeRefunds;

    // ================== ERRORS ==================

    error VaultNotSupported();
    error InvalidReceiver();
    error TokenMismatch();
    error InvalidZapExecutor();
    error SlippageExceeded();
    error NativeTransferFailed();

    // ================== INIT ==================

    event NativeRefundQueued(address indexed user, uint256 amount);
    event NativeRefundClaimed(address indexed user, uint256 amount);

    function __BaseAdapter_init(address _owner, address _queue, address _zapExecutor) internal onlyInitializing {
        // Initialize upgradeable mixins.
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        // Set ownership and default roles.
        _transferOwnership(_owner);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(OPERATOR_ROLE, _owner);

        // Wire optional queue and zap executor.
        depositQueue = _queue;
        zapExecutor = ZapExecutor(payable(_zapExecutor));
    }

    // ================== CORE LOGIC ==================

    /**
     * @dev Child contracts call this when they receive funds.
     * @param sourceId The source chain identifier (LZ EID or CCTP Domain)
     */
    function _processReceivedFunds(
        address user,
        uint32 sourceId,
        address token,
        uint256 amount, 
        uint256 nativeAmount,
        bytes32 messageId, // guid or messageHash
        bytes memory payload
    ) internal {
        // 1. Decode payload from source chain (vault, receiver, minSharesOut, zapCalls).
        (address vault, address receiver, uint256 minSharesOut, Call[] memory zapCalls) =
            abi.decode(payload, (address, address, uint256, Call[]));

        // Default receiver to the sender if not provided.
        if (receiver == address(0)) receiver = user;

        // 2. Record deposit for tracking and UX.
        uint256 depositId = _recordDeposit(receiver, sourceId, token, amount, vault, messageId);

        // 3. Validate vault allowlist before executing deposit.
        if (!supportedVaults[vault]) {
            _handleDepositFailure(
                depositId, token, amount, nativeAmount, abi.encodeWithSelector(VaultNotSupported.selector), minSharesOut, zapCalls
            );
            return;
        }

        // 4. Execute deposit via external call to enable try/catch.
        try this.executeStrategy{value: nativeAmount}(depositId, vault, receiver, token, amount, minSharesOut, zapCalls) returns (uint256 shares) {
            // Verify shares received meets user's minimum requirement
            if (shares < minSharesOut) {
                depositRecords[depositId].failureReason = abi.encodeWithSelector(SlippageExceeded.selector);
                _handleDepositFailure(
                    depositId, token, amount, nativeAmount, abi.encodeWithSelector(SlippageExceeded.selector), minSharesOut, zapCalls
                );
                return;
            }
            depositRecords[depositId].sharesReceived = shares;
            _updateDepositStatus(depositId, DepositStatus.Success);
            emit DepositSuccess(depositId, receiver, vault, shares);
        } catch (bytes memory reason) {
            depositRecords[depositId].failureReason = reason;
            _handleDepositFailure(depositId, token, amount, nativeAmount, reason, minSharesOut, zapCalls);
        }
    }

    /**
     * @notice Public function callable only by self (for try/catch context)
     * @param depositId Deposit ID for tracking
     * @param vault Vault address to deposit into
     * @param receiver Address to receive vault shares
     * @param token Input token address
     * @param amount Amount of tokens to deposit
     * @param minSharesOut Minimum shares user must receive (end-to-end slippage protection)
     * @param zapCalls Array of calls for zap execution (empty for direct deposit)
     * @return shares Amount of vault shares minted
     * @dev This function is called internally via try/catch to handle failures gracefully
     * @dev Payable to allow forwarding native value to ZapExecutor for zap paths that need native ETH
     */
    function executeStrategy(
        uint256 depositId,
        address vault,
        address receiver,
        address token,
        uint256 amount,
        uint256 minSharesOut,
        Call[] calldata zapCalls
    ) external payable onlySelf returns (uint256 shares) {
        if (zapCalls.length > 0) {
            // SECURITY: execute arbitrary calls only via ZapExecutor.
            if (address(zapExecutor) == address(0)) revert InvalidZapExecutor();

            // Approve ONLY the amount for this specific deposit.
            if (token != address(0) && amount > 0) {
                IERC20(token).forceApprove(address(zapExecutor), amount);
            }

            // Execute swaps and deposit in a sandboxed contract.
            // ZapExecutor enforces minSharesOut after zap + deposit.
            shares = zapExecutor.executeZapAndDeposit{value: msg.value}(
                token,
                amount,
                vault,
                receiver,
                minSharesOut,
                zapCalls
            );

            // Reset approval to minimize token approval risk.
            if (token != address(0) && amount > 0) {
                IERC20(token).forceApprove(address(zapExecutor), 0);
            }
            
            emit ZapExecuted(depositId, zapCalls.length, shares);
        } else {
            // Direct deposit path (token must match vault asset).
            address asset = IElitraVault(vault).asset();
            if (token != asset) revert TokenMismatch();

            // Approve and deposit directly into the vault.
            IERC20(asset).forceApprove(vault, amount);
            shares = IElitraVault(vault).deposit(amount, receiver);

            // Enforce end-to-end slippage protection.
            if (shares < minSharesOut) revert SlippageExceeded();

            // Reset approval for defensive safety.
            IERC20(asset).forceApprove(vault, 0);
        }
    }

    // ================== INTERNAL HELPERS ==================

    function _recordDeposit(
        address user,
        uint32 sourceId,
        address token,
        uint256 amount,
        address vault,
        bytes32 guid
    ) internal returns (uint256 depositId) {
        // Increment id first so the first deposit is id=0.
        depositId = totalDeposits++;
        depositRecords[depositId] = DepositRecord({
            user: user,
            srcEid: sourceId, // Mapped to srcEid in interface struct
            tokenIn: token,
            amountIn: amount,
            vault: vault,
            sharesReceived: 0,
            timestamp: block.timestamp,
            status: DepositStatus.Pending,
            guid: guid,
            failureReason: ""
        });
        // Track deposits per user for convenience.
        userDepositIds[user].push(depositId);
        emit DepositRecorded(depositId, user, vault, amount, sourceId);
    }

    function _updateDepositStatus(uint256 depositId, DepositStatus newStatus) internal {
        // Update status for UI/monitoring.
        depositRecords[depositId].status = newStatus;
    }

    function _handleDepositFailure(
        uint256 depositId,
        address token,
        uint256 amount,
        uint256 nativeAmount,
        bytes memory reason,
        uint256 minSharesOut,
        Call[] memory zapCalls
    ) internal {
        address user = depositRecords[depositId].user;

        if (depositQueue == address(0)) {
            // No queue configured: refund immediately.
            _refundAssets(user, token, amount, nativeAmount);
            _updateDepositStatus(depositId, DepositStatus.DepositFailed);
            emit DepositFailed(depositId, user, reason);
            return;
        }

        // Try to enqueue for later resolution by operators.
        try this._enqueueFailedDeposit{value: nativeAmount}(
            depositId, token, amount, nativeAmount, reason, minSharesOut, zapCalls
        ) {
            _updateDepositStatus(depositId, DepositStatus.Queued);
            emit DepositQueued(depositId, user, reason);
        } catch {
            // Queue failed - fallback to refund.
            _refundAssets(user, token, amount, nativeAmount);
            _updateDepositStatus(depositId, DepositStatus.DepositFailed);
            emit DepositFailed(depositId, user, reason);
        }
    }

    function _enqueueFailedDeposit(
        uint256 depositId,
        address token,
        uint256 amount,
        uint256 nativeAmount,
        bytes memory reason,
        uint256 minSharesOut,
        Call[] calldata zapCalls
    ) external payable onlySelf {
        require(msg.value == nativeAmount, "Native amount mismatch");

        // Load record to pass full context to the queue.
        DepositRecord storage record = depositRecords[depositId];

        // Approve queue to pull ERC20 tokens for custody.
        if (token != address(0) && amount > 0) {
            IERC20(token).forceApprove(depositQueue, amount);
        }

        // Snapshot share price for later user-facing reconciliation.
        uint256 sharePrice = IElitraVault(record.vault).lastPricePerShare();

        ICrosschainDepositQueue(depositQueue).recordFailedDeposit{value: nativeAmount}(
            record.user,
            record.srcEid,
            token,
            amount,
            nativeAmount,
            record.vault,
            record.guid,
            reason,
            sharePrice,
            minSharesOut,
            zapCalls
        );
    }

    function _refundAssets(address user, address token, uint256 amount, uint256 nativeAmount) internal {
        if (token != address(0) && amount > 0) {
            IERC20(token).safeTransfer(user, amount);
        }
        if (nativeAmount > 0) {
            (bool ok, ) = payable(user).call{value: nativeAmount}("");
            if (!ok) {
                pendingNativeRefunds[user] += nativeAmount;
                emit NativeRefundQueued(user, nativeAmount);
            }
        }
    }

    /// @notice Claim native refunds that could not be pushed during failure handling
    /// @param user User whose pending native refund will be claimed
    /// @param recipient Recipient of claimed native refund
    function claimNativeRefund(address user, address payable recipient) external nonReentrant {
        require(msg.sender == user || msg.sender == owner(), "Not authorized");
        require(recipient != address(0), "Invalid recipient");

        uint256 refund = pendingNativeRefunds[user];
        if (refund == 0) revert NativeTransferFailed();

        pendingNativeRefunds[user] = 0;
        (bool ok, ) = recipient.call{value: refund}("");
        if (!ok) {
            pendingNativeRefunds[user] = refund;
            revert NativeTransferFailed();
        }

        emit NativeRefundClaimed(user, refund);
    }

    // ================== ADMIN ==================

    /// @notice Set the zap executor contract address
    /// @param _executor Address of the ZapExecutor contract
    function setZapExecutor(address _executor) external onlyOwner {
        // Allow owner to rotate zap executor implementation.
        zapExecutor = ZapExecutor(payable(_executor));
    }

    /// @notice Set the deposit queue contract address
    /// @param _queue Address of the CrosschainDepositQueue contract
    function setDepositQueue(address _queue) external onlyOwner {
        // Allow owner to set/disable the queue.
        depositQueue = _queue;
    }

    /// @notice Enable or disable a vault for cross-chain deposits
    /// @param vault Address of the vault
    /// @param isActive True to enable, false to disable
    function setSupportedVault(address vault, bool isActive) external onlyOwner {
        // Toggle vault allowlist.
        supportedVaults[vault] = isActive;
    }
    
    /// @notice Grant operator role to an address
    /// @param operator Address to grant operator role to
    function setOperator(address operator) external onlyOwner {
        // Grant operator role for day-to-day ops.
        grantRole(OPERATOR_ROLE, operator);
    }
    
    /// @notice Revoke operator role from an address
    /// @param operator Address to revoke operator role from
    function removeOperator(address operator) external onlyOwner {
        // Revoke operator role.
        revokeRole(OPERATOR_ROLE, operator);
    }

    /// @notice Pause the adapter (prevents new deposits)
    function pause() external onlyOwnerOrOperator {
        // Pause to stop new cross-chain deposits.
        _pause();
    }

    /// @notice Unpause the adapter (allows new deposits)
    function unpause() external onlyOwnerOrOperator {
        // Unpause to resume deposits.
        _unpause();
    }
    
    /// @notice Emergency recovery function to transfer tokens or native currency
    /// @param token Token address (address(0) for native currency)
    /// @param to Recipient address
    /// @param amount Amount to transfer
    function emergencyRecover(address token, address to, uint256 amount) external onlyOwner {
        // Allow owner to recover stranded assets.
        if (token == address(0)) payable(to).transfer(amount);
        else IERC20(token).safeTransfer(to, amount);
    }

    /// @notice Transfer ownership and update roles
    /// @param newOwner New owner address
    /// @dev Transfers ownership and grants/revokes admin and operator roles accordingly
    function transferOwnership(address newOwner) public override onlyOwner {
        address oldOwner = owner();
        // Skip no-op transfer.
        if (newOwner == oldOwner) return;

        super.transferOwnership(newOwner);

        // Move admin/operator roles along with ownership.
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
        _grantRole(OPERATOR_ROLE, newOwner);
        _revokeRole(DEFAULT_ADMIN_ROLE, oldOwner);
        _revokeRole(OPERATOR_ROLE, oldOwner);
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    // ================== VIEW ==================
    
    /// @notice Get deposit record by deposit ID
    /// @param depositId Deposit ID to query
    /// @return Deposit record containing all deposit information
    function getDepositRecord(uint256 depositId) external view returns (DepositRecord memory) {
        // Expose deposit record for UI/monitoring.
        return depositRecords[depositId];
    }
    
    /// @notice Get all deposit IDs for a user
    /// @param user User address to query
    /// @return Array of deposit IDs for the user
    function getUserDepositIds(address user) external view returns (uint256[] memory) {
        // Expose per-user deposit list.
        return userDepositIds[user];
    }
    
    /// @notice Check if a vault is supported for cross-chain deposits
    /// @param vault Vault address to check
    /// @return True if vault is supported, false otherwise
    function isVaultSupported(address vault) external view returns (bool) {
        // Allowlist query helper.
        return supportedVaults[vault];
    }

    // ================== MODIFIERS ==================

    modifier onlySelf() {
        // Only allow internal try/catch entrypoint.
        require(msg.sender == address(this), "Only self");
        _;
    }

    modifier onlyOwnerOrOperator() {
        // Owner or operator can run ops actions.
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not authorized");
        _;
    }
}
