# Elitra Protocol

![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

## Overview

Elitra Protocol provides a modular, ERC4626-compliant vault designed for cross-chain asset management and optimized
liquidity operations. The vault enables users to deposit assets while providing operators with controlled management
capabilities, including asset transfers, redemptions, and fee handling. The contract architecture allows seamless
integration with external strategies, oracles, and cross-chain liquidity mechanisms.

## Key Features

- **ERC4626 Compatibility**: Implements the ERC4626 vault standard for tokenized vaults.
- **Asynchronous Redemption**: Users can request asset redemptions, which are fulfilled by an operator.
- **Cross-Chain Liquidity Management**: Supports integrations with external liquidity sources and strategies.
- **Fee Mechanism**: Configurable deposit and withdrawal fees, with a designated fee recipient.
- **Access Control**: Role-based authorization via an upgradable `AuthUpgradeable` contract.
- **Oracle Integration**: Fetches and updates underlying balances from an oracle.
- **Pausability**: The contract can be paused in case of unexpected market events.

## Contracts Structure

### Core Contracts

- **[`ElitraVault.sol`](https://github.com/elitra/core/blob/main/src/ElitraVault.sol)**: Implements the main vault
  functionality, including deposits, redemptions, and balance tracking.
- **[`Escrow.sol`](https://github.com/elitra/core/blob/main/src/Escrow.sol)**: An escrow contract for controlled asset
  withdrawals.
- **[`Compatible.sol`](https://github.com/elitra/core/blob/main/src/base/Compatible.sol)**: Allows the contract to
  receive ETH and ERC721/ERC1155 tokens.
- **[`AuthUpgradeable.sol`](https://github.com/elitra/core/blob/main/src/base/AuthUpgradable.sol)**: Upgradable access
  control contract.
