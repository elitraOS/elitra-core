// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { LayerZeroCrosschainDepositAdapter } from "../../src/adapters/layerzero/LzCrosschainDepositAdapter.sol";

/**
 * @title Configure_DVNs_Adapter
 * @notice Script to configure LayerZero DVNs for CrosschainDepositAdapter
 * @dev Sets up required and optional DVNs for cross-chain message verification
 *
 * Usage:
 *   forge script script/crosschain-deposit/Configure_DVNs_Adapter.s.sol:Configure_DVNs_Adapter \
 *     --rpc-url $SEI_RPC_URL \
 *     --broadcast \
 *     -vvv
 *
 * Environment Variables:
 *   LZ_CROSSCHAIN_ADAPTER_ADDRESS - CrosschainDepositAdapter proxy address
 *   LZ_ENDPOINT_V2 - LayerZero V2 endpoint address
 *   LZ_RECEIVE_ULN_302 - ReceiveUln302 library address
 *   SOURCE_EID - Source chain endpoint ID (e.g., Ethereum)
 */
contract Configure_DVNs_Adapter is Script {
    // LayerZero DVN addresses on SEI
    // Update these with actual SEI chain DVN addresses
    address public constant LZ_DVN = 0x6788f52439ACA6BFF597d3eeC2DC9a44B8FEE842; // LayerZero DVN
    address public constant GOOGLE_CLOUD_DVN = 0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc; // Google Cloud DVN
    address public constant NETHERMIND_DVN = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5; // Nethermind DVN

    // LayerZero endpoint IDs
    uint32 public constant ETH_EID = 30101; // Ethereum
    uint32 public constant ARB_EID = 30110; // Arbitrum
    uint32 public constant BASE_EID = 30184; // Base
    uint32 public constant SEI_EID = 30280; // SEI

    // Config types
    uint32 public constant CONFIG_TYPE_ULN = 2;
    uint32 public constant CONFIG_TYPE_EXECUTOR = 1;

    /**
     * @notice UlnConfig struct for LayerZero
     */
    struct UlnConfig {
        uint64 confirmations;
        uint8 requiredDVNCount;
        uint8 optionalDVNCount;
        uint8 optionalDVNThreshold;
        address[] requiredDVNs;
        address[] optionalDVNs;
    }


    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n=== Configuring DVNs for CrosschainDepositAdapter ===\n");

        // Get configuration from environment
        address adapterAddress = vm.envAddress("LZ_CROSSCHAIN_DEPOSIT_ADAPTER_ADDRESS");
        address endpoint = vm.envAddress("LZ_ENDPOINT_V2");
        address receiveUln302 = vm.envAddress("LZ_RECEIVE_ULN_302");
        uint32 sourceEid = uint32(vm.envOr("LZ_SOURCE_EID", uint256(ETH_EID)));

        console.log("Configuration:");
        console.log("  Deployer:", deployer);
        console.log("  Adapter:", adapterAddress);
        console.log("  Endpoint:", endpoint);
        console.log("  ReceiveUln302:", receiveUln302);
        console.log("  Source EID:", sourceEid);
        console.log("");

        LayerZeroCrosschainDepositAdapter adapter = LayerZeroCrosschainDepositAdapter(payable(adapterAddress));

        // Verify we're the owner
        address owner = adapter.owner();
        require(owner == deployer, "Caller is not adapter owner");
        console.log("Owner verified:", owner);

        vm.startBroadcast(deployerPrivateKey);

        // Configure DVNs for receiving messages from source chain
        _configureDVNs(endpoint, receiveUln302, adapterAddress, sourceEid);

        vm.stopBroadcast();

        console.log("\n=== DVN Configuration Complete ===\n");
       
    }

    /**
     * @notice Configure DVNs for a specific source chain
     */
    function _configureDVNs(
        address endpoint,
        address receiveUln302,
        address adapterAddress,
        uint32 sourceEid
    ) internal {
        console.log("\nConfiguring DVNs for source EID:", sourceEid);

        // Prepare DVN config - using 2 required DVNs for security
        address[] memory requiredDVNs = new address[](2);
        requiredDVNs[0] = LZ_DVN;
        requiredDVNs[1] = GOOGLE_CLOUD_DVN;

        // No optional DVNs for now
        address[] memory optionalDVNs = new address[](0);

        // Set confirmations based on source chain
        uint64 confirmations;
        if (sourceEid == ETH_EID) {
            confirmations = 15; // Ethereum: 15 blocks (~3 minutes)
        } else if (sourceEid == ARB_EID) {
            confirmations = 20; // Arbitrum: 20 blocks
        } else if (sourceEid == BASE_EID) {
            confirmations = 20; // Base: 20 blocks
        } else {
            confirmations = 15; // Default: 15 blocks
        }

        // Encode ULN config
        bytes memory ulnConfig = abi.encode(
            UlnConfig({
                confirmations: confirmations,
                requiredDVNCount: 2,
                optionalDVNCount: 0,
                optionalDVNThreshold: 0,
                requiredDVNs: requiredDVNs,
                optionalDVNs: optionalDVNs
            })
        );

        // Build SetConfigParam array
        IEndpointV2.SetConfigParam[] memory params = new IEndpointV2.SetConfigParam[](1);
        params[0] = IEndpointV2.SetConfigParam({
            eid: sourceEid,
            configType: CONFIG_TYPE_ULN,
            config: ulnConfig
        });

        console.log("DVN Configuration:");
        console.log("  Required DVNs:");
        console.log("    - LayerZero DVN:", LZ_DVN);
        console.log("    - Google Cloud DVN:", GOOGLE_CLOUD_DVN);
        console.log("  Optional DVNs: None");
        console.log("  Confirmations:", confirmations);
        console.log("");

        // Set config on endpoint
        console.log("Setting DVN config on endpoint...");
        IEndpointV2(endpoint).setConfig(
            adapterAddress,
            receiveUln302,
            params
        );

        console.log("DVN config set successfully");
    }

    /**
     * @notice Configure DVNs for multiple source chains
     */
    function configureMultipleChains(
        address endpoint,
        address receiveUln302,
        address adapterAddress,
        uint32[] memory sourceEids
    ) public {
        console.log("\nConfiguring DVNs for multiple source chains...");
        console.log("Number of chains:", sourceEids.length);

        for (uint256 i = 0; i < sourceEids.length; i++) {
            console.log("\n--- Chain %s of %s ---", i + 1, sourceEids.length);
            _configureDVNs(endpoint, receiveUln302, adapterAddress, sourceEids[i]);
        }

        console.log("\nAll chains configured");
    }

    function test() public {
        // Required for forge coverage to work
    }
}

/**
 * @notice LayerZero Endpoint V2 interface
 */
interface IEndpointV2 {
    struct SetConfigParam {
        uint32 eid;
        uint32 configType;
        bytes config;
    }

    function setConfig(
        address oappAddress,
        address sendLibrary,
        SetConfigParam[] calldata params
    ) external;

    function getConfig(
        address oappAddress,
        address lib,
        uint32 eid,
        uint32 configType
    ) external view returns (bytes memory config);
}
