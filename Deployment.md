# 1. Deploy ElitraVaultFactory
```bash
 forge script script/deploy/Deploy_Factory.s.sol --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

2. Deploy FeeRegistry
```bash
 forge script script/deploy/Deploy_FeeRegistry.s.sol --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

3. Deploy ElitraVault
```bash
 forge script script/deploy/Deploy_ElitraVault.sol --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```


4. Deploy Authority
```bash
 forge script script/deploy/DeployAuthority.s.sol --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

5. Deploy RolesAuthority
```bash
 forge script script/deploy/DeployRolesAuthority.s.sol --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```