// SPDX-License-Identifier: MIT
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

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ================== STATE VARIABLES ==================
    
    uint256 public totalDeposits;
    mapping(uint256 => DepositRecord) public depositRecords;
    mapping(address => uint256[]) public userDepositIds;
    mapping(address => bool) public supportedVaults;
    
    address public depositQueue;
    ZapExecutor public zapExecutor;

    // ================== ERRORS ==================
    
    error VaultNotSupported();
    error InvalidReceiver();
    error TokenMismatch();
    error InvalidZapExecutor();

    // ================== INIT ==================

    function __BaseAdapter_init(address _owner, address _queue, address _zapExecutor) internal onlyInitializing {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _transferOwnership(_owner);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(OPERATOR_ROLE, _owner);

        depositQueue = _queue;
        zapExecutor = ZapExecutor(_zapExecutor);
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
        bytes32 messageId, // guid or messageHash
        bytes memory payload
    ) internal {
        // 1. Decode Payload
        (address vault, address receiver, uint256 minAmountOut, Call[] memory zapCalls) = 
            abi.decode(payload, (address, address, uint256, Call[]));

        if (receiver == address(0)) receiver = user;

        // 2. Record Deposit
        uint256 depositId = _recordDeposit(receiver, sourceId, token, amount, vault, messageId);

        // 3. Validate
        // 3. Validate
        if (!supportedVaults[vault]) {
            _handleDepositFailure(depositId, token, amount, abi.encodeWithSelector(VaultNotSupported.selector), minAmountOut, zapCalls);
            return;
        }

        // 4. Execute with Try/Catch
        try this.executeStrategy(depositId, vault, receiver, token, amount, minAmountOut, zapCalls) returns (uint256 shares) {
            depositRecords[depositId].sharesReceived = shares;
            _updateDepositStatus(depositId, DepositStatus.Success);
            emit DepositSuccess(depositId, receiver, vault, shares);
        } catch (bytes memory reason) {
            depositRecords[depositId].failureReason = reason;
            _handleDepositFailure(depositId, token, amount, reason, minAmountOut, zapCalls);
        }
    }

    /**
     * @notice Public function callable only by self (for try/catch context)
     */
    function executeStrategy(
        uint256 depositId,
        address vault,
        address receiver,
        address token,
        uint256 amount,
        uint256 minAmountOut,
        Call[] calldata zapCalls
    ) external onlySelf returns (uint256 shares) {
        if (zapCalls.length > 0) {
            // SECURITY: Use ZapExecutor
            if (address(zapExecutor) == address(0)) revert InvalidZapExecutor();

            // Approve ONLY the amount for this specific deposit
            IERC20(token).forceApprove(address(zapExecutor), amount);

            // Execute in sandbox
            shares = zapExecutor.executeZapAndDeposit(
                token,
                amount,
                vault,
                receiver,
                minAmountOut,
                zapCalls
            );

            // Reset approval
            IERC20(token).forceApprove(address(zapExecutor), 0);
            
            emit ZapExecuted(depositId, zapCalls.length, shares);
        } else {
            // Direct deposit
            address asset = IElitraVault(vault).asset();
            if (token != asset) revert TokenMismatch();

            IERC20(asset).forceApprove(vault, amount);
            shares = IElitraVault(vault).deposit(amount, receiver);

            // Reset approval for defensive safety
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
        userDepositIds[user].push(depositId);
        emit DepositRecorded(depositId, user, vault, amount, sourceId);
    }

    function _updateDepositStatus(uint256 depositId, DepositStatus newStatus) internal {
        depositRecords[depositId].status = newStatus;
    }

    function _handleDepositFailure(
        uint256 depositId,
        address token,
        uint256 amount,
        bytes memory reason,
        uint256 minAmountOut,
        Call[] memory zapCalls
    ) internal {
        address user = depositRecords[depositId].user;
        
        if (depositQueue == address(0)) {
            // No queue - return to user
            IERC20(token).safeTransfer(user, amount);
            _updateDepositStatus(depositId, DepositStatus.DepositFailed);
            emit DepositFailed(depositId, user, reason);
            return;
        }

        try this._enqueueFailedDeposit(depositId, token, amount, reason, minAmountOut, zapCalls) {
            _updateDepositStatus(depositId, DepositStatus.Queued);
            emit DepositQueued(depositId, user, reason);
        } catch {
            // Queue failed - return to user
            IERC20(token).safeTransfer(user, amount);
            _updateDepositStatus(depositId, DepositStatus.DepositFailed);
            emit DepositFailed(depositId, user, reason);
        }
    }

    function _enqueueFailedDeposit(
        uint256 depositId,
        address token,
        uint256 amount,
        bytes memory reason,
        uint256 minAmountOut,
        Call[] calldata zapCalls
    ) external onlySelf {
        IERC20(token).forceApprove(depositQueue, amount);

        // get share price
        uint256 sharePrice = IElitraVault(depositRecords[depositId].vault).lastPricePerShare();

        ICrosschainDepositQueue(depositQueue).recordFailedDeposit(
            depositRecords[depositId].user,
            depositRecords[depositId].srcEid,
            token,
            amount,
            depositRecords[depositId].vault,
            depositRecords[depositId].guid,
            reason,
            sharePrice,
            minAmountOut,
            zapCalls
        );
    }

    // ================== ADMIN ==================

    function setZapExecutor(address _executor) external onlyOwner {
        zapExecutor = ZapExecutor(_executor);
    }

    function setDepositQueue(address _queue) external onlyOwner {
        depositQueue = _queue;
    }

    function setSupportedVault(address vault, bool isActive) external onlyOwner {
        supportedVaults[vault] = isActive;
    }
    
    function setOperator(address operator) external onlyOwner {
        grantRole(OPERATOR_ROLE, operator);
    }
    
    function removeOperator(address operator) external onlyOwner {
        revokeRole(OPERATOR_ROLE, operator);
    }

    function pause() external onlyOwnerOrOperator {
        _pause();
    }

    function unpause() external onlyOwnerOrOperator {
        _unpause();
    }
    
    function emergencyRecover(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0)) payable(to).transfer(amount);
        else IERC20(token).safeTransfer(to, amount);
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        address oldOwner = owner();
        if (newOwner == oldOwner) return;

        super.transferOwnership(newOwner);

        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
        _grantRole(OPERATOR_ROLE, newOwner);
        _revokeRole(DEFAULT_ADMIN_ROLE, oldOwner);
        _revokeRole(OPERATOR_ROLE, oldOwner);
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner {}

    // ================== VIEW ==================
    
    function getDepositRecord(uint256 depositId) external view returns (DepositRecord memory) {
        return depositRecords[depositId];
    }
    
    function getUserDepositIds(address user) external view returns (uint256[] memory) {
        return userDepositIds[user];
    }
    
    function isVaultSupported(address vault) external view returns (bool) {
        return supportedVaults[vault];
    }

    // ================== MODIFIERS ==================

    modifier onlySelf() {
        require(msg.sender == address(this), "Only self");
        _;
    }

    modifier onlyOwnerOrOperator() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender), "Not authorized");
        _;
    }
}
