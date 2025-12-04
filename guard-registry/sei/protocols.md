
### ERC4626 / Morpho (ERC4626Adapter)

- **Assets / Target vault**
  - **SEI vault**: `0x948FcC6b7f68f4830Cd69dB1481a9e1A142A4923`
  - **USDC vault**: `0x015f10a56e97e02437d294815d8e079e1903e41c`
- **Invest (deposit)** – `generateDepositCalldata`
  - Step 1 
    - **Target**: underlying ERC20 `assetAddress`
    - **Function**: `approve(address spender, uint256 amount)`
    - **Args**:
      - `spender = erc4626VaultAddress` (SEI/USDC vault above)
      - `amount = assets`
  - Step 2 
    - **Target**: `erc4626VaultAddress`
    - **Function**: `deposit(uint256 assets, address receiver)`
    - **Args**:
      - `assets = amount`
      - `receiver = vaultAddress` (the Elitra vault)
- **Withdraw** – `generateWithdrawCalldata`
  - Step 1
    - **Target**: `erc4626VaultAddress`
    - **Function**: `withdraw(uint256 assets, address receiver, address owner)`
    - **Args**:
      - `assets = amount`
      - `receiver = vaultAddress`
      - `owner = vaultAddress`
- **Rewards**
  - **Not implemented yet** 

---

### Takara (TakaraAdapter + Comptroller)

- **Takara Pool (per-asset)**
  - **SEI pool**: `0xA26b9BFe606d29F16B5Aecf30F9233934452c4E2`
  - **USDC pool**: `0xd1E6a6F58A29F64ab2365947ACb53EfEB6Cc05e0`
- **Takara Comptroller**
  - **SEI, USDC**: `0x71034bf5eC0FAd7aEE81a213403c8892F3d8CAeE`
- **Invest (mint)** – `generateDepositCalldata`
  - Step 1 
    - **Target**: underlying ERC20 `assetAddress`
    - **Function**: `approve(address spender, uint256 amount)`
    - **Args**:
      - `spender = takaraPoolAddress` (SEI/USDC pool above)
      - `amount = mintAmount`
  - Step 2 
    - **Target**: `takaraPoolAddress`
    - **Function**: `mint(uint256 mintAmount)`
    - **Args**:
      - `mintAmount = amount`
- **Withdraw (redeem)** – `generateWithdrawCalldata`
  - Step 1
    - **Target**: `takaraPoolAddress`
    - **Function**: `redeem(uint256 redeemAmount)`
    - **Args**:
      - `redeemAmount = amount`
- **Rewards (Takara Comptroller guard)**
  - Step 1
    - **Target**: Comptroller `0x71034bf5eC0FAd7aEE81a213403c8892F3d8CAeE`
    - **Function**: `claimReward()`
    - **Args**: none

---

### Yei (YeiAdapter + Incentives Controller)

- **Yei Pool**
  - **SEI, USDC**: `0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638`
- **Yei Incentives Controller**
  - **SEI, USDC**: `0x60485C5E5E3D535B16CC1bd2C9243C7877374259`
- **Invest (supply)** – `generateDepositCalldata`
  - Step 1 
    - **Target**: underlying ERC20 `assetAddress`
    - **Function**: `approve(address spender, uint256 amount)`
    - **Args**:
      - `spender = yeiPoolAddress` (`0x4a4d9a...b638`)
      - `amount = deposit amount`
  - Step 2 
    - **Target**: `yeiPoolAddress`
    - **Function**:  
      `supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)`
    - **Args**:
      - `asset = assetAddress` (SEI/USDC token)
      - `amount = deposit amount`
      - `onBehalfOf = vaultAddress` (Elitra vault)
      - `referralCode = 0`
- **Withdraw** – `generateWithdrawCalldata`
  - Step 1
    - **Target**: `yeiPoolAddress`
    - **Function**:  
      `withdraw(address asset, uint256 amount, address to)`
    - **Args**:
      - `asset = assetAddress`
      - `amount = withdraw amount`
      - `to = vaultAddress`
- **Rewards (Yei Incentives Controller guard)**
  - Step 1
    - **Target**: Incentives Controller `0x60485C5E5E3D535B16CC1bd2C9243C7877374259`
    - **Function**:  
      `claimAllRewardsToSelf(address[] assets)`
    - **Args**:
      - `assets = [assetAddress]` (e.g. `[SEI]` or `[USDC]` depending on vault)
