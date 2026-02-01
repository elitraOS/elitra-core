// SPDX-License-Identifier: MIT
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

    error ZapFailed();
    error SlippageExceeded();
    error ZapProducedNoOutput();
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

        // Sweep tokens 
        sweepToken(tokenIn);
        sweepNative();
    }

    /// @notice Sweep any remaining token dust from the contract
    /// @param token Token address to sweep
    /// @dev Contract is designed to be stateless - allows anyone to sweep dust tokens
    function sweepToken(address token) public {
        if (IERC20(token).balanceOf(address(this)) == 0) return;
        IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    /// @notice Sweep any remaining native currency from the contract
    /// @dev Contract is designed to be stateless - allows anyone to sweep dust native currency
    function sweepNative() public {
        if (address(this).balance == 0) return;
        payable(msg.sender).transfer(address(this).balance);
    }
}

