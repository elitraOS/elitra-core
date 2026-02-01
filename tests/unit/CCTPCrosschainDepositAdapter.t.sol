// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { CCTPCrosschainDepositAdapter } from "../../src/crosschain-adapters/cctp/CCTPCrosschainDepositAdapter.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { Call } from "../../src/interfaces/IVaultBase.sol";
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
}
