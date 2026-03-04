// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { CCTPCrosschainDepositAdapter } from "../../src/crosschain-adapters/cctp/CCTPCrosschainDepositAdapter.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { Call } from "../../src/interfaces/IVaultBase.sol";
import { IMessageTransmitterV2 } from "../../src/interfaces/external/cctp/IMessageTransmitterV2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CCTPCrosschainDepositAdapter_Test is Test {
    CCTPCrosschainDepositAdapter public implementation;
    CCTPCrosschainDepositAdapter public adapter;
    ERC20Mock public usdc;
    address public owner;
    address public queue;
    address public zapExecutor;
    address public transmitter;

    function setUp() public {
        owner = makeAddr("owner");
        queue = makeAddr("queue");
        zapExecutor = makeAddr("zapExecutor");
        transmitter = makeAddr("transmitter");

        usdc = new ERC20Mock();

        // Deploy implementation and proxy
        implementation = new CCTPCrosschainDepositAdapter();

        bytes memory initData = abi.encodeWithSelector(
            CCTPCrosschainDepositAdapter.initialize.selector,
            owner,
            transmitter,
            address(usdc),
            queue,
            zapExecutor
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        adapter = CCTPCrosschainDepositAdapter(payable(address(proxy)));
    }

    // =========================================
    // initialize
    // =========================================

    function test_Initialize_SetsOwner() public view {
        assertEq(adapter.owner(), owner);
    }

    function test_Initialize_SetsMessageTransmitter() public view {
        assertEq(address(adapter.messageTransmitter()), transmitter);
    }

    function test_Initialize_SetsUSDC() public view {
        assertEq(adapter.usdc(), address(usdc));
    }

    function test_Initialize_SetsQueue() public view {
        assertEq(adapter.depositQueue(), queue);
    }

    function test_Initialize_SetsZapExecutor() public view {
        assertEq(address(adapter.zapExecutor()), zapExecutor);
    }

    function test_Initialize_RevertsWhenZeroTransmitter() public {
        CCTPCrosschainDepositAdapter newImpl = new CCTPCrosschainDepositAdapter();

        bytes memory initData = abi.encodeWithSelector(
            CCTPCrosschainDepositAdapter.initialize.selector,
            owner,
            address(0),
            address(usdc),
            queue,
            zapExecutor
        );

        vm.expectRevert(CCTPCrosschainDepositAdapter.InvalidMessageTransmitter.selector);
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Initialize_RevertsWhenZeroUSDC() public {
        CCTPCrosschainDepositAdapter newImpl = new CCTPCrosschainDepositAdapter();

        bytes memory initData = abi.encodeWithSelector(
            CCTPCrosschainDepositAdapter.initialize.selector,
            owner,
            transmitter,
            address(0),
            queue,
            zapExecutor
        );

        vm.expectRevert(CCTPCrosschainDepositAdapter.InvalidUSDC.selector);
        new ERC1967Proxy(address(newImpl), initData);
    }

    // =========================================
    // encodeHookData
    // =========================================

    function test_EncodeHookData_ReturnsCorrectEncoding() public {
        address vault = makeAddr("vault");
        address receiver = makeAddr("receiver");
        uint256 minAmountOut = 100e18;

        bytes memory data = adapter.encodeHookData(vault, receiver, minAmountOut, new Call[](0));

        (address decodedVault, address decodedReceiver, uint256 decodedMinAmount,) =
            abi.decode(data, (address, address, uint256, Call[]));

        assertEq(decodedVault, vault);
        assertEq(decodedReceiver, receiver);
        assertEq(decodedMinAmount, minAmountOut);
    }

    function test_EncodeHookData_WithZapCalls() public {
        address vault = makeAddr("vault");
        address receiver = makeAddr("receiver");
        uint256 minAmountOut = 100e18;

        Call[] memory zapCalls = new Call[](1);
        zapCalls[0] = Call({
            target: makeAddr("target"),
            data: abi.encodeWithSelector(bytes4(0x12345678)),
            value: 0
        });

        bytes memory data = adapter.encodeHookData(vault, receiver, minAmountOut, zapCalls);

        (address decodedVault, address decodedReceiver, uint256 decodedMinAmount, Call[] memory decodedCalls) =
            abi.decode(data, (address, address, uint256, Call[]));

        assertEq(decodedVault, vault);
        assertEq(decodedReceiver, receiver);
        assertEq(decodedMinAmount, minAmountOut);
        assertEq(decodedCalls.length, 1);
        assertEq(decodedCalls[0].target, zapCalls[0].target);
    }

    // =========================================
    // constants
    // =========================================

    function test_SupportedMessageVersion() public {
        assertEq(adapter.SUPPORTED_MESSAGE_VERSION(), 1);
    }

    function test_SupportedBodyVersion() public {
        assertEq(adapter.SUPPORTED_BODY_VERSION(), 1);
    }

    // =========================================
    // relay
    // =========================================

    function test_Relay_ZeroReceiverDefaultsToMessageSender() public {
        MockMessageTransmitter transmitterMock = new MockMessageTransmitter(address(usdc));
        _deployAdapterWithTransmitter(address(transmitterMock), address(0));

        MockVault vault = new MockVault(address(usdc), false);
        address sender = makeAddr("sender");
        uint256 amount = 100e6;

        vm.prank(owner);
        adapter.setSupportedVault(address(vault), true);

        bytes memory hookData = abi.encode(address(vault), address(0), 0, new Call[](0));
        bytes memory message = _buildCctpMessage(7, address(adapter), sender, amount, hookData);

        (bool relaySuccess, bool hookSuccess) = adapter.relay(message, "");

        assertTrue(relaySuccess);
        assertTrue(hookSuccess);
        assertEq(vault.sharesOf(sender), amount);
        assertEq(vault.sharesOf(address(adapter)), 0);
    }

    function test_Relay_UnsupportedVaultRefundsToMessageSender() public {
        MockMessageTransmitter transmitterMock = new MockMessageTransmitter(address(usdc));
        _deployAdapterWithTransmitter(address(transmitterMock), address(0));

        address sender = makeAddr("sender");
        address unsupportedVault = makeAddr("unsupportedVault");
        uint256 amount = 100e6;

        bytes memory hookData = abi.encode(unsupportedVault, address(0), 0, new Call[](0));
        bytes memory message = _buildCctpMessage(7, address(adapter), sender, amount, hookData);

        (bool relaySuccess, bool hookSuccess) = adapter.relay(message, "");

        assertTrue(relaySuccess);
        assertTrue(hookSuccess);
        assertEq(usdc.balanceOf(sender), amount);
        assertEq(usdc.balanceOf(address(adapter)), 0);
    }

    // =========================================
    // Helpers
    // =========================================

    function _deployAdapterWithTransmitter(address _transmitter, address _queue) internal {
        CCTPCrosschainDepositAdapter newImpl = new CCTPCrosschainDepositAdapter();
        bytes memory initData = abi.encodeWithSelector(
            CCTPCrosschainDepositAdapter.initialize.selector,
            owner,
            _transmitter,
            address(usdc),
            _queue,
            zapExecutor
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(newImpl), initData);
        adapter = CCTPCrosschainDepositAdapter(payable(address(proxy)));
    }

    function _buildCctpMessage(
        uint32 sourceDomain,
        address mintRecipient,
        address messageSender,
        uint256 amount,
        bytes memory hookData
    ) internal pure returns (bytes memory) {
        bytes4 messageVersion = bytes4(uint32(1));
        bytes4 sourceDomainBytes = bytes4(sourceDomain);
        bytes memory headerPadding = new bytes(140);
        bytes memory header = bytes.concat(messageVersion, sourceDomainBytes, headerPadding);

        bytes4 bodyVersion = bytes4(uint32(1));
        bytes32 burnToken = bytes32(0);
        bytes32 mintRecipientBytes32 = bytes32(uint256(uint160(mintRecipient)));
        bytes32 amountBytes32 = bytes32(amount);
        bytes32 messageSenderBytes32 = bytes32(uint256(uint160(messageSender)));
        bytes32 maxFee = bytes32(0);
        bytes32 feeExecuted = bytes32(0);
        bytes32 expirationBlock = bytes32(0);

        bytes memory body = abi.encodePacked(
            bodyVersion,
            burnToken,
            mintRecipientBytes32,
            amountBytes32,
            messageSenderBytes32,
            maxFee,
            feeExecuted,
            expirationBlock
        );

        return bytes.concat(header, body, hookData);
    }
}

contract MockMessageTransmitter is IMessageTransmitterV2 {
    ERC20Mock public immutable usdc;

    constructor(address _usdc) {
        usdc = ERC20Mock(_usdc);
    }

    function receiveMessage(bytes calldata message, bytes calldata) external returns (bool success) {
        // Message body starts at offset 148.
        bytes calldata messageBody = message[148:];
        address mintRecipient = address(uint160(uint256(bytes32(messageBody[36:68]))));
        uint256 amount = uint256(bytes32(messageBody[68:100]));
        usdc.mint(mintRecipient, amount);
        return true;
    }

    function localDomain() external pure returns (uint32) {
        return 0;
    }

    function nextAvailableNonce() external pure returns (uint64) {
        return 0;
    }

    function usedNonces(uint32, bytes32) external pure returns (bool) {
        return false;
    }
}

contract MockVault {
    address public asset;
    bool public shouldRevert;
    mapping(address => uint256) public sharesOf;

    constructor(address _asset, bool _shouldRevert) {
        asset = _asset;
        shouldRevert = _shouldRevert;
    }

    function deposit(uint256 amount, address receiver) external returns (uint256) {
        if (shouldRevert) revert("Deposit failed");
        ERC20Mock(asset).transferFrom(msg.sender, address(this), amount);
        sharesOf[receiver] += amount;
        return amount;
    }
}
