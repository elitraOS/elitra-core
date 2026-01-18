// SPDX-License-Identifier: MIT
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

    uint256 public totalFailedDeposits;
    
    mapping(uint256 => FailedDeposit) public failedDeposits;
    mapping(address => uint256[]) public userFailedDepositIds;
    mapping(address => bool) public registeredAdapters;

    address public zapExecutor;

    // ========================================= INITIALIZER =========================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        require(_owner != address(0), "Invalid owner");

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(OPERATOR_ROLE, _owner);
    }

    // ========================================= MODIFIERS =========================================

    modifier onlyAdapter() {
        require(registeredAdapters[msg.sender], "Only registered adapter");
        _;
    }

    modifier onlyOwnerOrOperator() {
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
        address vault,
        bytes32 guid,
        bytes calldata reason,
        uint256 sharePrice,
        uint256 minAmountOut,
        Call[] calldata zapCalls
    ) external override onlyAdapter {
        // Transfer tokens from adapter to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 depositId = totalFailedDeposits++;

        failedDeposits[depositId] = FailedDeposit({
            user: user,
            srcEid: srcEid,
            token: token,
            amount: amount,
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

        userFailedDepositIds[user].push(depositId);

        emit FailedDepositRecorded(depositId, user, token, msg.sender, amount, sharePrice, reason);
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function refundFailedDeposit(uint256 depositId) external override onlyOwnerOrOperator {
        FailedDeposit storage deposit = failedDeposits[depositId];
        require(deposit.status == DepositStatus.Failed, "Not failed status");
        require(deposit.user != address(0), "Invalid recipient");

        deposit.status = DepositStatus.Resolved;

        IERC20(deposit.token).safeTransfer(deposit.user, deposit.amount);

        emit DepositResolved(depositId, deposit.user, deposit.token, deposit.amount, false);
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function fulfillFailedDeposit(
        uint256 depositId,
        uint256 minSharesOut,
        Call[] calldata zapCalls
    ) external override onlyOwnerOrOperator returns (uint256 sharesOut) {
        FailedDeposit storage deposit = failedDeposits[depositId];
        require(deposit.status == DepositStatus.Failed, "Not failed status");
        require(minSharesOut > 0, "minSharesOut=0");
        require(deposit.vault != address(0), "Invalid vault");

        IElitraVault vault = IElitraVault(deposit.vault);
        address vaultAsset = vault.asset();

        if (deposit.token == vaultAsset) {
            // Direct deposit path
            IERC20(vaultAsset).safeApprove(address(vault), 0);
            IERC20(vaultAsset).safeApprove(address(vault), deposit.amount);

            sharesOut = vault.deposit(deposit.amount, deposit.user);
            require(sharesOut >= minSharesOut, "Shares below minimum");
        } else {
            // Zap path - verify zapCalls matches original attested data
            require(zapExecutor != address(0), "Zap executor not set");
            require(
                keccak256(abi.encode(zapCalls)) == deposit.zapCallsHash,
                "zapCalls mismatch"
            );

            IERC20(deposit.token).safeApprove(zapExecutor, 0);
            IERC20(deposit.token).safeApprove(zapExecutor, deposit.amount);

            sharesOut = ZapExecutor(zapExecutor).executeZapAndDeposit(
                deposit.token,
                deposit.amount,
                deposit.vault,
                deposit.user,
                deposit.minAmountOut, // Use original attested minAmountOut
                zapCalls
            );
            require(sharesOut >= minSharesOut, "Shares below minimum");
        }

        deposit.status = DepositStatus.Resolved;

        emit DepositResolved(depositId, deposit.user, deposit.token, deposit.amount, true);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function setAdapterRegistration(address _adapter, bool _registered) external override onlyOwnerOrOperator {
        require(_adapter != address(0), "Invalid adapter");
        registeredAdapters[_adapter] = _registered;
        emit AdapterRegistered(_adapter, _registered);
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function setZapExecutor(address exec) external override onlyOwnerOrOperator {
        require(exec != address(0), "Invalid zap executor");
        zapExecutor = exec;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function getFailedDeposit(uint256 depositId) external view override returns (FailedDeposit memory) {
        return failedDeposits[depositId];
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function getUserFailedDeposits(address user) external view override returns (uint256[] memory) {
        return userFailedDepositIds[user];
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function isAdapterRegistered(address _adapter) external view override returns (bool) {
        return registeredAdapters[_adapter];
    }
}
