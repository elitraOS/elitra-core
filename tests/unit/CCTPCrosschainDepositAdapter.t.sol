// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { CCTPCrosschainDepositAdapter } from "../../src/adapters/cctp/CCTPCrosschainDepositAdapter.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { Call } from "../../src/interfaces/IVaultBase.sol";

contract CCTPCrosschainDepositAdapter_Test is Test {
    CCTPCrosschainDepositAdapter public adapter;
    ERC20Mock public usdc;
    address public owner;
    address public queue;
    address public zapExecutor;

    function setUp() public {
        owner = makeAddr("owner");
        queue = makeAddr("queue");
        zapExecutor = makeAddr("zapExecutor");

        usdc = new ERC20Mock();

        adapter = new CCTPCrosschainDepositAdapter();
        adapter.initialize(owner, makeAddr("transmitter"), address(usdc), queue, zapExecutor);
    }

    // =========================================
    // initialize
    // =========================================

    function test_Initialize_SetsOwner() public {
        assertEq(adapter.owner(), owner);
    }

    function test_Initialize_SetsMessageTransmitter() public {
        assertEq(address(adapter.messageTransmitter()), makeAddr("transmitter"));
    }

    function test_Initialize_SetsUSDC() public {
        assertEq(adapter.usdc(), address(usdc));
    }

    function test_Initialize_SetsQueue() public {
        assertEq(adapter.depositQueue(), queue);
    }

    function test_Initialize_SetsZapExecutor() public {
        assertEq(address(adapter.zapExecutor()), zapExecutor);
    }

    function test_Initialize_RevertsWhenZeroTransmitter() public {
        CCTPCrosschainDepositAdapter newAdapter = new CCTPCrosschainDepositAdapter();

        vm.expectRevert(CCTPCrosschainDepositAdapter.InvalidMessageTransmitter.selector);
        newAdapter.initialize(owner, address(0), address(usdc), queue, zapExecutor);
    }

    function test_Initialize_RevertsWhenZeroUSDC() public {
        CCTPCrosschainDepositAdapter newAdapter = new CCTPCrosschainDepositAdapter();

        vm.expectRevert(CCTPCrosschainDepositAdapter.InvalidUSDC.selector);
        newAdapter.initialize(owner, makeAddr("transmitter"), address(0), queue, zapExecutor);
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

    function test_SupportedMessageVersion() public view {
        assertEq(adapter.SUPPORTED_MESSAGE_VERSION(), 1);
    }

    function test_SupportedBodyVersion() public view {
        assertEq(adapter.SUPPORTED_BODY_VERSION(), 1);
    }
}
