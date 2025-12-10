// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IElitraVault } from "../interfaces/IElitraVault.sol";
import { Call } from "../interfaces/IVaultBase.sol";

/**
 * @title ZapExecutor
 * @notice Helper contract to isolate arbitrary external calls from the main adapter.
 * @dev This contract is stateless and holds no funds between transactions.
 */
contract ZapExecutor {
    using SafeERC20 for IERC20;

    error ZapFailed();
    error SlippageExceeded();
    error ZapProducedNoOutput();
    error DepositFailedNoShares();

    /**
     * @notice Execute zap and deposit to vault
     * @dev This contract must hold 0 funds before and after this call
     */
    function executeZapAndDeposit(
        address tokenIn,
        uint256 amountIn,
        address vault,
        address receiver,
        uint256 minAmountOut,
        Call[] calldata zapCalls
    ) external returns (uint256 shares) {
        // 1. Pull funds from Adapter
        // (Adapter must have approved this contract beforehand)
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // 2. Execute Zaps
        for (uint256 i = 0; i < zapCalls.length; i++) {
            (bool success, ) = zapCalls[i].target.call{value: zapCalls[i].value}(zapCalls[i].data);
            if (!success) revert ZapFailed();
        }

        // 3. Check Output
        address asset = IElitraVault(vault).asset();
        uint256 balance = IERC20(asset).balanceOf(address(this));
        
        if (balance < minAmountOut) revert SlippageExceeded();
        if (balance == 0) revert ZapProducedNoOutput();

        // 4. Deposit to Vault
        IERC20(asset).forceApprove(vault, balance);
        shares = IElitraVault(vault).deposit(balance, receiver);

        if (shares == 0) revert DepositFailedNoShares();

        // 5. Sweep any remaining input tokens back to receiver (dust)
        uint256 remaining = IERC20(tokenIn).balanceOf(address(this));
        if (remaining > 0) {
            IERC20(tokenIn).safeTransfer(receiver, remaining);
        }
    }
}

