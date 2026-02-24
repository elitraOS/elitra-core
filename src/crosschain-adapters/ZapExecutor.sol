// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IElitraVault } from "../interfaces/IElitraVault.sol";
import { Call } from "../interfaces/IVaultBase.sol";

/**
 * @title ZapExecutor
 * @notice Helper contract to isolate arbitrary external calls from the main adapter.
 * @dev This contract is stateless and holds no funds after the call
 */
contract ZapExecutor {
    using SafeERC20 for IERC20;

    // Raised when any zap call fails.
    error ZapFailed();
    // Raised when output is below caller-specified minAmountOut.
    error SlippageExceeded();
    // Raised when zap produced no vault asset at all.
    error ZapProducedNoOutput();
    // Raised when vault deposit mints zero shares.
    error DepositFailedNoShares();

    /**
     * @notice Execute zap and deposit to vault
     * @param tokenIn Input token address
     * @param amountIn Amount of input tokens to swap
     * @param vault Vault address to deposit into
     * @param receiver Address to receive vault shares
     * @param minAmountOut Minimum amount of vault asset expected from zap
     * @param zapCalls Array of calls to execute for the zap (swaps, etc.)
     * @return shares Amount of vault shares minted to receiver
     * @dev This contract must hold 0 funds before and after this call. Reverts if zap fails, slippage exceeded, or deposit produces no shares
     */
    function executeZapAndDeposit(
        address tokenIn,
        uint256 amountIn,
        address vault,
        address receiver,
        uint256 minAmountOut,
        Call[] calldata zapCalls
    ) external returns (uint256 shares) {
        // 1. Pull funds from Adapter.
        // (Adapter must have approved this contract beforehand.)
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // 2. Execute arbitrary zap calls (swaps, unwraps, etc.).
        for (uint256 i = 0; i < zapCalls.length; i++) {
            (bool success, ) = zapCalls[i].target.call{value: zapCalls[i].value}(zapCalls[i].data);
            if (!success) revert ZapFailed();
        }

        // 3. Check output amount in vault asset.
        address asset = IElitraVault(vault).asset();
        uint256 balance = IERC20(asset).balanceOf(address(this));
        
        // Enforce slippage limit and non-zero output.
        if (balance < minAmountOut) revert SlippageExceeded();
        if (balance == 0) revert ZapProducedNoOutput();

        // 4. Deposit to vault and mint shares for receiver.
        IERC20(asset).forceApprove(vault, balance);
        shares = IElitraVault(vault).deposit(balance, receiver);

        if (shares == 0) revert DepositFailedNoShares();

        // Sweep any leftover tokens/native to keep executor stateless.
        sweepToken(tokenIn);
        sweepNative();
    }

    /// @notice Sweep any remaining token dust from the contract
    /// @param token Token address to sweep
    /// @dev Contract is designed to be stateless - allows anyone to sweep dust tokens
    function sweepToken(address token) public {
        // Anyone can sweep dust since the contract should be stateless.
        if (IERC20(token).balanceOf(address(this)) == 0) return;
        IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    /// @notice Sweep any remaining native currency from the contract
    /// @dev Contract is designed to be stateless - allows anyone to sweep dust native currency
    function sweepNative() public {
        // Sweep any native dust (e.g., from swap refunds).
        uint256 bal = address(this).balance;
        if (bal == 0) return;
        (bool ok, ) = payable(msg.sender).call{ value: bal }("");
        if (!ok) revert ZapFailed();
    }
}
