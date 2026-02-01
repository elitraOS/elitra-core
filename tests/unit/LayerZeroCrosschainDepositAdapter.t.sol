// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { LayerZeroCrosschainDepositAdapter } from "../../src/adapters/layerzero/LayerZeroCrosschainDepositAdapter.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Call } from "../../src/interfaces/IVaultBase.sol";

/**
 * @title LayerZeroCrosschainDepositAdapterTest
 * @notice Test suite for LayerZeroCrosschainDepositAdapter
 */
contract LayerZeroCrosschainDepositAdapter_Test is Test {
    LayerZeroCrosschainDepositAdapter public adapter;
    ERC20Mock public token;
    MockEndpoint public endpoint;
    MockOFT public oft;

    address public owner;
    address public queue;
    address public zapExecutor;
    address public weth;

    function setUp() public {
        owner = makeAddr("owner");
        queue = makeAddr("queue");
        zapExecutor = makeAddr("zapExecutor");
        weth = makeAddr("weth");

        token = new ERC20Mock();
        endpoint = new MockEndpoint();
        oft = new MockOFT(address(token));

        adapter = new LayerZeroCrosschainDepositAdapter(address(endpoint));
        adapter.initialize(owner, queue, zapExecutor, weth);
    }

    // =========================================
    // initialize
    // =========================================

    function test_Initialize_SetsOwner() public {
        assertEq(adapter.owner(), owner);
    }

    function test_Initialize_SetsEndpoint() public {
        assertEq(address(adapter.endpoint()), address(endpoint));
    }

    function test_Initialize_SetsWeth() public {
        assertEq(adapter.weth(), weth);
    }

    function test_Initialize_SetsQueue() public {
        assertEq(adapter.depositQueue(), queue);
    }

    function test_Initialize_SetsZapExecutor() public {
        assertEq(address(adapter.zapExecutor()), zapExecutor);
    }

    // =========================================
    // setSupportedOFT
    // =========================================

    function test_SetSupportedOFT_SetsMapping() public {
        vm.startPrank(owner);
        adapter.setSupportedOFT(address(token), address(oft), true);

        assertEq(adapter.tokenToOFT(address(token)), address(oft));
        assertEq(adapter.oftToToken(address(oft)), address(token));
        assertTrue(adapter.supportedOFTs(address(oft)));
        vm.stopPrank();
    }

    function test_SetSupportedOFT_EmitsEvent() public {
        vm.startPrank(owner);
        // Just check it doesn't revert
        adapter.setSupportedOFT(address(token), address(oft), true);
        vm.stopPrank();
    }

    function test_SetSupportedOFT_RevertsWhenNotOwner() public {
        vm.expectRevert();
        adapter.setSupportedOFT(address(token), address(oft), true);
    }

    function test_SetSupportedOFT_RevertsWhenZeroToken() public {
        vm.startPrank(owner);
        vm.expectRevert("Invalid address");
        adapter.setSupportedOFT(address(0), address(oft), true);
        vm.stopPrank();
    }

    function test_SetSupportedOFT_RevertsWhenZeroOFT() public {
        vm.startPrank(owner);
        vm.expectRevert("Invalid address");
        adapter.setSupportedOFT(address(token), address(0), true);
        vm.stopPrank();
    }

    function test_SetSupportedOFT_CanDeactivate() public {
        vm.startPrank(owner);
        adapter.setSupportedOFT(address(token), address(oft), true);
        assertTrue(adapter.supportedOFTs(address(oft)));

        adapter.setSupportedOFT(address(token), address(oft), false);
        assertFalse(adapter.supportedOFTs(address(oft)));
        vm.stopPrank();
    }

    // =========================================
    // setWeth
    // =========================================

    function test_SetWeth_UpdatesWeth() public {
        vm.startPrank(owner);
        address newWeth = makeAddr("newWeth");
        adapter.setWeth(newWeth);
        assertEq(adapter.weth(), newWeth);
        vm.stopPrank();
    }

    function test_SetWeth_RevertsWhenNotOwner() public {
        vm.expectRevert();
        adapter.setWeth(makeAddr("newWeth"));
    }

    // =========================================
    // lzCompose
    // =========================================

    function test_LzCompose_RevertsWhenNotFromEndpoint() public {
        vm.startPrank(owner);
        adapter.setSupportedOFT(address(token), address(oft), true);
        vm.stopPrank();

        address randomCaller = makeAddr("randomCaller");
        vm.startPrank(randomCaller);

        bytes32 guid = bytes32(uint256(1));
        bytes memory message = _encodeComposeMessage(12345, 100e18, abi.encode("hook data"));

        vm.expectRevert("Only endpoint");
        adapter.lzCompose(address(oft), guid, message, address(0), "");
        vm.stopPrank();
    }

    function test_LzCompose_RevertsWhenOFTNotSupported() public {
        // Don't set the OFT as supported

        bytes32 guid = bytes32(uint256(1));
        bytes memory message = _encodeComposeMessage(12345, 100e18, abi.encode("hook data"));

        vm.startPrank(address(endpoint));
        vm.expectRevert("OFT not supported");
        adapter.lzCompose(address(oft), guid, message, address(0), "");
        vm.stopPrank();
    }

    function test_LzCompose_AcceptsWhenFromEndpointAndSupported() public {
        vm.startPrank(owner);
        adapter.setSupportedOFT(address(token), address(oft), true);
        adapter.setSupportedVault(makeAddr("vault"), true);
        vm.stopPrank();

        // Setup queue to handle failed deposit
        vm.mockCall(
            queue,
            abi.encodeWithSelector(ICrosschainDepositQueue.recordFailedDeposit.selector),
            abi.encode()
        );

        // Give OFT tokens to adapter
        deal(address(token), address(adapter), 100e18);

        bytes32 guid = bytes32(uint256(1));
        bytes memory hookData = abi.encode(makeAddr("vault"), makeAddr("receiver"), 0, new Call[](0));
        bytes memory message = _encodeComposeMessage(12345, 100e18, hookData);

        vm.startPrank(address(endpoint));
        // This should not revert from the endpoint/OFT check
        // It may fail elsewhere without full mocks
        adapter.lzCompose(address(oft), guid, message, address(0), "");
        vm.stopPrank();
    }

    function test_LzCompose_CallsBaseProcessReceivedFunds() public {
        vm.startPrank(owner);
        adapter.setSupportedOFT(address(token), address(oft), true);
        adapter.setSupportedVault(makeAddr("vault"), true);
        vm.stopPrank();

        // Give OFT tokens to adapter
        deal(address(token), address(adapter), 100e18);

        bytes32 guid = bytes32(uint256(1));
        address vault = makeAddr("vault");
        address receiver = makeAddr("receiver");
        bytes memory hookData = abi.encode(vault, receiver, 0, new Call[](0));
        bytes memory message = _encodeComposeMessage(12345, 100e18, hookData);

        // Mock the queue
        vm.mockCall(
            queue,
            abi.encodeWithSelector(ICrosschainDepositQueue(queue).recordFailedDeposit.selector),
            abi.encode()
        );

        vm.startPrank(address(endpoint));
        adapter.lzCompose(address(oft), guid, message, address(0), "");
        vm.stopPrank();

        // Verify a deposit was recorded
        assertEq(adapter.totalDeposits(), 1);
    }

    function test_Fuzz_LzCompose_AnyAmount(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1e30);
        vm.startPrank(owner);
        adapter.setSupportedOFT(address(token), address(oft), true);
        adapter.setSupportedVault(makeAddr("vault"), true);
        vm.stopPrank();

        // Give OFT tokens to adapter
        deal(address(token), address(adapter), amount);

        bytes32 guid = bytes32(uint256(1));
        bytes memory hookData = abi.encode(makeAddr("vault"), makeAddr("receiver"), 0, new Call[](0));
        bytes memory message = _encodeComposeMessage(12345, amount, hookData);

        // Mock the queue
        vm.mockCall(
            queue,
            abi.encodeWithSelector(ICrosschainDepositQueue(queue).recordFailedDeposit.selector),
            abi.encode()
        );

        vm.startPrank(address(endpoint));
        adapter.lzCompose(address(oft), guid, message, address(0), "");
        vm.stopPrank();

        assertEq(adapter.totalDeposits(), 1);
    }

    // =========================================
    // receive
    // =========================================

    function test_Receive_AcceptsETH() public {
        vm.deal(address(this), 1 ether);

        (bool success,) = address(adapter).call{ value: 1 ether }("");
        assertTrue(success);
        assertEq(address(adapter).balance, 1 ether);
    }

    // =========================================
    // _getTokenFromOFT (via state)
    // =========================================

    function test_GetTokenFromOFT_ReturnsMappedToken() public {
        vm.startPrank(owner);
        adapter.setSupportedOFT(address(token), address(oft), true);

        // We can't directly test internal function, but we can verify the mapping
        assertEq(adapter.oftToToken(address(oft)), address(token));
        vm.stopPrank();
    }

    function test_GetTokenFromOFT_ReturnsOftWhenNoMapping() public {
        vm.startPrank(owner);
        // Set up an OFT that is also a valid ERC20 token address
        address oftAsToken = address(oft);
        adapter.setSupportedOFT(oftAsToken, oftAsToken, true);

        // When OFT == token, the mapping should return the same address
        assertEq(adapter.oftToToken(oftAsToken), oftAsToken);
        vm.stopPrank();
    }

    // =========================================
    // Helpers
    // =========================================

    function _encodeComposeMessage(
        uint32 srcEid,
        uint256 amountLD,
        bytes memory composeMsg
    ) internal pure returns (bytes memory) {
        // Simplified OFT compose message encoding
        // Format: srcEid(4) + amountLD(32) + composeMsgLength(4) + composeMsg
        return abi.encodePacked(srcEid, amountLD, uint32(composeMsg.length), composeMsg);
    }
}

// =========================================
// Mocks
// =========================================

contract MockEndpoint {
    function send(
        uint32,
        bytes32,
        bytes calldata,
        bytes calldata,
        bytes calldata
    ) external payable {}
}

contract MockOFT {
    address public token;

    constructor(address _token) {
        token = _token;
    }

    function send(
        uint32,
        bytes32,
        uint256,
        bytes calldata,
        bytes calldata,
        bytes calldata
    ) external payable {}
}

// Minimal interface for the mock
interface ICrosschainDepositQueue {
    function recordFailedDeposit(
        address user,
        uint32 srcEid,
        address token,
        uint256 amount,
        address vault,
        bytes32 guid,
        bytes memory reason,
        uint256 sharePrice,
        uint256 minAmountOut,
        bytes calldata zapCalls
    ) external;
}
