// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ICrosschainDepositQueue } from "../../interfaces/ICrosschainDepositQueue.sol";

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

    address public adapter;
    uint256 public totalFailedDeposits;
    
    mapping(uint256 => FailedDeposit) public failedDeposits;
    mapping(address => uint256[]) public userFailedDepositIds;

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
        require(msg.sender == adapter, "Only adapter");
        _;
    }

    modifier onlyOperator() {
        require(hasRole(OPERATOR_ROLE, msg.sender), "Only operator");
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
        bytes calldata reason
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
            guid: guid,
            failureReason: reason,
            timestamp: block.timestamp,
            status: DepositStatus.Failed
        });

        userFailedDepositIds[user].push(depositId);

        emit FailedDepositRecorded(depositId, user, token, amount, reason);
    }

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function resolveFailedDeposit(uint256 depositId, address recipient) external override onlyOperator {
        FailedDeposit storage deposit = failedDeposits[depositId];
        require(deposit.status == DepositStatus.Failed, "Not failed status");
        require(recipient != address(0), "Invalid recipient");

        deposit.status = DepositStatus.Resolved;

        IERC20(deposit.token).safeTransfer(recipient, deposit.amount);

        emit DepositResolved(depositId, deposit.user, deposit.token, deposit.amount, false);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @inheritdoc ICrosschainDepositQueue
     */
    function setAdapter(address _adapter) external override onlyOperator {
        require(_adapter != address(0), "Invalid adapter");
        adapter = _adapter;
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
}

