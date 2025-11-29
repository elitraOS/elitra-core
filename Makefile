verify:
	forge verify-contract \
		--verifier etherscan \
		--chain-id 1 \
		--verifier-url $(VERIFIER_URL) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(CONTRACT_ADDRESS) \
		$(CONTRACT_NAME)

verify-erc1967-proxy:
	forge verify-contract \
		0x6E00Fc2897803a98856a9029De74C9f95CfE17E0 \
		lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy \
		--chain-id 1 \
		--verifier-url https://api.etherscan.io/v2/api \
		--etherscan-api-key $ETHERSCAN_API_KEY \          
		--compiler-version 0.8.28 \
		--evm-version cancun \
		  --constructor-args $(cast abi-encode "constructor(address,address,bytes)" 0x2a75D11c3D289873698cAfcA1196A12C0e82e1aa 0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4 $(cast abi-encode "initialize(address)" 0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4))