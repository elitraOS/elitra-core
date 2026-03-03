// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ICrosschainDepositQueue } from "../interfaces/ICrosschainDepositQueue.sol";
import { Call } from "../interfaces/IVaultBase.sol";
import { IElitraVault } from "../interfaces/IElitraVault.sol";
import { ZapExecutor } from "./ZapExecutor.sol";

/**
 * @title CrosschainDepositQueue
 * @notice Holds funds from failed cross-chain deposits for later resolution
 */
contract CrosschainDepositQueue is 
    Initializable, 
    AccessControlUpgradeable, 
    UUPSUpgradeable, 
    ICrosschainDepositQueue 
{
    using SafeERC20 for IERC20;

    // ========================================= CONSTANTS =========================================

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ========================================= STATE VARIABLES =========================================

    // Monotonic id counter for failed deposits.
    uint256 public totalFailedDeposits;

    // DepositId => failed deposit record.
    mapping(uint256 => FailedDeposit) public failedDeposits;
    // User => list of failed deposit ids.
    mapping(address => uint256[]) public userFailedDepositIds;
    // Adapters allowed to enqueue failed deposits.
    mapping(address => bool) public registeredAdapters;

    // Zap executor used for fulfillment when token != vault asset.
    address public zapExecutor;

    // ========================================= INITIALIZER =========================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        // Require a valid owner for admin/operator roles.
        require(_owner != address(0), "Invalid owner");

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(OPERATOR_ROLE, _owner);
    }

    // ========================================= MODIFIERS =========================================

    modifier onlyAdapter() {
        // Only trusted adapters can enqueue failed deposits.
        require(registeredAdapters[msg.sender], "Only registered adapter");
        _;
    }

    modifier onlyOwnerOrOperator() {
        // Owner or operator can resolve deposits.
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender),
            "Not owner or operator"
        );
        _;
    }

    // ========================================= CORE FUNCTIONS =========================================

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function recordFailedDeposit(
        address user,
        uint32 srcEid,
        address token,
        uint256 amount,
        uint256 nativeAmount,
        address vault,
        bytes32 guid,
        bytes calldata reason,
        uint256 sharePrice,
        uint256 minAmountOut,
        Call[] calldata zapCalls
    ) external payable override onlyAdapter {
        // Keep native sidecar funds for failed zap retry/refund.
        require(msg.value == nativeAmount, "Native amount mismatch");

        // Transfer ERC20 tokens from adapter to this contract for custody.
        if (token != address(0) && amount > 0) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        // Allocate a new failed deposit id.
        uint256 depositId = totalFailedDeposits++;

        failedDeposits[depositId] = FailedDeposit({
            user: user,
            srcEid: srcEid,
            token: token,
            amount: amount,
            nativeAmount: nativeAmount,
            vault: vault,
            adapter: msg.sender,
            guid: guid,
            failureReason: reason,
            timestamp: block.timestamp,
            sharePrice: sharePrice,
            minAmountOut: minAmountOut,
            zapCallsHash: keccak256(abi.encode(zapCalls)),
            status: DepositStatus.Failed
        });

        // Track per-user failed deposits.
        userFailedDepositIds[user].push(depositId);

        emit FailedDepositRecorded(depositId, user, token, msg.sender, amount, sharePrice, reason);
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function refundFailedDeposit(uint256 depositId) external override {
        FailedDeposit storage deposit = failedDeposits[depositId];
        // Only unresolved failed deposits can be refunded.
        require(deposit.status == DepositStatus.Failed, "Not failed status");
        require(deposit.user != address(0), "Invalid recipient");

        // Allow either owner/operator OR the original user to refund.
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || 
            hasRole(OPERATOR_ROLE, msg.sender) || 
            msg.sender == deposit.user,
            "Not authorized"
        );

        // Mark resolved before transferring funds out.
        deposit.status = DepositStatus.Resolved;

        // Return original tokens to the user.
        if (deposit.token != address(0) && deposit.amount > 0) {
            IERC20(deposit.token).safeTransfer(deposit.user, deposit.amount);
        }
        if (deposit.nativeAmount > 0) {
            (bool ok, ) = payable(deposit.user).call{value: deposit.nativeAmount}("");
            require(ok, "ETH transfer failed");
        }

        emit DepositResolved(depositId, deposit.user, deposit.token, deposit.amount, false);
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     * @param depositId The failed deposit id
     */
    function fulfillFailedDeposit(
        uint256 depositId,
        uint256 minSharesOut,
        Call[] calldata zapCalls
    ) external override onlyOwnerOrOperator returns (uint256 sharesOut) {
        FailedDeposit storage deposit = failedDeposits[depositId];
        // Only unresolved failed deposits can be fulfilled.
        require(deposit.status == DepositStatus.Failed, "Not failed status");
        require(minSharesOut > 0, "minSharesOut=0");
        require(deposit.vault != address(0), "Invalid vault");

        IElitraVault vault = IElitraVault(deposit.vault);
        address vaultAsset = vault.asset();

        if (deposit.token == vaultAsset && deposit.nativeAmount == 0) {
            // Direct deposit path (token already matches vault asset).
            IERC20(vaultAsset).forceApprove(address(vault), deposit.amount);

            sharesOut = vault.deposit(deposit.amount, deposit.user);

            // Reset approval for defensive safety.
            IERC20(vaultAsset).forceApprove(address(vault), 0);

            require(sharesOut >= minSharesOut, "Shares below minimum");
        } else {
            // Zap path - verify zapCalls matches original attested data.
            require(zapExecutor != address(0), "Zap executor not set");
            require(
                keccak256(abi.encode(zapCalls)) == deposit.zapCallsHash,
                "zapCalls mismatch"
            );

            // Approve executor for this amount.
            if (deposit.token != address(0) && deposit.amount > 0) {
                IERC20(deposit.token).forceApprove(zapExecutor, deposit.amount);
            }

            sharesOut = ZapExecutor(payable(zapExecutor)).executeZapAndDeposit{value: deposit.nativeAmount}(
                deposit.token,
                deposit.amount,
                deposit.vault,
                deposit.user,
                deposit.minAmountOut, // Use original attested minAmountOut
                zapCalls
            );

            // Reset approval for defensive safety.
            if (deposit.token != address(0) && deposit.amount > 0) {
                IERC20(deposit.token).forceApprove(zapExecutor, 0);
            }

            require(sharesOut >= minSharesOut, "Shares below minimum");
        }

        // Mark resolved after successful fulfillment.
        deposit.status = DepositStatus.Resolved;

        emit DepositResolved(depositId, deposit.user, deposit.token, deposit.amount, true);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function setAdapterRegistration(address _adapter, bool _registered) external override onlyOwnerOrOperator {
        // Validate adapter address before registration.
        require(_adapter != address(0), "Invalid adapter");
        registeredAdapters[_adapter] = _registered;
        emit AdapterRegistered(_adapter, _registered);
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function setZapExecutor(address exec) external override onlyOwnerOrOperator {
        // Zap executor must be configured for zap-based fulfillments.
        require(exec != address(0), "Invalid zap executor");
        zapExecutor = exec;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function getFailedDeposit(uint256 depositId) external view override returns (FailedDeposit memory) {
        // Expose failed deposit record for UI.
        return failedDeposits[depositId];
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function getUserFailedDeposits(address user) external view override returns (uint256[] memory) {
        // Expose per-user failed deposits.
        return userFailedDepositIds[user];
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function isAdapterRegistered(address _adapter) external view override returns (bool) {
        // Query adapter registration status.
        return registeredAdapters[_adapter];
    }

    // ========================================= RECOVERY FUNCTIONS =========================================

    /// @notice Accept native ETH (required for ZapExecutor sweep)
    receive() external payable {}

    /// @notice Recover stuck ERC20 tokens
    /// @param token Token address to recover
    /// @param to Recipient address
    /// @param amount Amount to recover (0 for full balance)
    function recoverToken(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Recover ERC20 dust; amount=0 means full balance.
        require(to != address(0), "Invalid recipient");
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 toRecover = amount == 0 ? balance : amount;
        require(toRecover <= balance, "Insufficient balance");
        IERC20(token).safeTransfer(to, toRecover);
    }

    /// @notice Recover stuck native ETH
    /// @param to Recipient address
    /// @param amount Amount to recover (0 for full balance)
    function recoverNative(address payable to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Recover native dust; amount=0 means full balance.
        require(to != address(0), "Invalid recipient");
        uint256 balance = address(this).balance;
        uint256 toRecover = amount == 0 ? balance : amount;
        require(toRecover <= balance, "Insufficient balance");
        (bool success, ) = to.call{value: toRecover}("");
        require(success, "ETH transfer failed");
    }
}
