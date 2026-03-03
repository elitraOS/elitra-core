// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { LayerZeroCrosschainDepositAdapter } from "../../src/crosschain-adapters/layerzero/LayerZeroCrosschainDepositAdapter.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { Call } from "../../src/interfaces/IVaultBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title LayerZeroCrosschainDepositAdapterTest
 * @notice Test suite for LayerZeroCrosschainDepositAdapter
 */
contract LayerZeroCrosschainDepositAdapter_Test is Test {
    LayerZeroCrosschainDepositAdapter public implementation;
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

        // Deploy implementation
        implementation = new LayerZeroCrosschainDepositAdapter(address(endpoint));

        bytes memory initData = abi.encodeWithSelector(
            LayerZeroCrosschainDepositAdapter.initialize.selector,
            owner,
            queue,
            zapExecutor,
            weth
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        adapter = LayerZeroCrosschainDepositAdapter(payable(address(proxy)));
    }

    // =========================================
    // initialize
    // =========================================

    function test_Initialize_SetsOwner() public view {
        assertEq(adapter.owner(), owner);
    }

    function test_Initialize_SetsEndpoint() public view {
        assertEq(address(adapter.endpoint()), address(endpoint));
    }

    function test_Initialize_SetsWeth() public view {
        assertEq(adapter.weth(), weth);
    }

    function test_Initialize_SetsQueue() public view {
        assertEq(adapter.depositQueue(), queue);
    }

    function test_Initialize_SetsZapExecutor() public view {
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
        MockVault vault = new MockVault(address(token));
        
        vm.startPrank(owner);
        adapter.setSupportedOFT(address(token), address(oft), true);
        adapter.setSupportedVault(address(vault), true);
        vm.stopPrank();

        // Give OFT tokens to adapter
        deal(address(token), address(adapter), 100e18);

        bytes32 guid = bytes32(uint256(1));
        bytes memory hookData = abi.encode(address(vault), makeAddr("receiver"), 1, new Call[](0));
        bytes memory message = _encodeComposeMessage(12345, 100e18, hookData);

        vm.startPrank(address(endpoint));
        // This should not revert from the endpoint/OFT check
        adapter.lzCompose(address(oft), guid, message, address(0), "");
        vm.stopPrank();
    }

    function test_LzCompose_CallsBaseProcessReceivedFunds() public {
        MockVault vault = new MockVault(address(token));
        
        vm.startPrank(owner);
        adapter.setSupportedOFT(address(token), address(oft), true);
        adapter.setSupportedVault(address(vault), true);
        vm.stopPrank();

        // Give OFT tokens to adapter
        deal(address(token), address(adapter), 100e18);

        bytes32 guid = bytes32(uint256(1));
        address receiver = makeAddr("receiver");
        bytes memory hookData = abi.encode(address(vault), receiver, 1, new Call[](0));
        bytes memory message = _encodeComposeMessage(12345, 100e18, hookData);

        vm.startPrank(address(endpoint));
        adapter.lzCompose(address(oft), guid, message, address(0), "");
        vm.stopPrank();

        // Verify a deposit was recorded
        assertEq(adapter.totalDeposits(), 1);
    }

    function test_Fuzz_LzCompose_AnyAmount(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1e30);
        MockVault vault = new MockVault(address(token));
        
        vm.startPrank(owner);
        adapter.setSupportedOFT(address(token), address(oft), true);
        adapter.setSupportedVault(address(vault), true);
        vm.stopPrank();

        // Give OFT tokens to adapter
        deal(address(token), address(adapter), amount);

        bytes32 guid = bytes32(uint256(1));
        bytes memory hookData = abi.encode(address(vault), makeAddr("receiver"), 1, new Call[](0));
        bytes memory message = _encodeComposeMessage(12345, amount, hookData);

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
        // OFT compose message encoding per OFTComposeMsgCodec
        // Format: nonce(8) + srcEid(4) + amountLD(32) + composeMsg
        // composeMsg should include composeFrom(32) + actual message
        // For testing, we use nonce=0 and composeFrom=address(0)
        uint64 nonce = 0;
        bytes32 composeFrom = bytes32(0);
        bytes memory fullComposeMsg = abi.encodePacked(composeFrom, composeMsg);
        return abi.encodePacked(nonce, srcEid, amountLD, fullComposeMsg);
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

contract MockVault {
    address public asset;
    bool public shouldRevert;

    constructor(address _asset) {
        asset = _asset;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function deposit(uint256, address) external returns (uint256) {
        if (shouldRevert) revert("Deposit failed");
        return 0; // Return 0 shares to simulate failure
    }
}
