// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";
import { Api3SwapAdapter } from "src/adapters/Api3SwapAdapter.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IApi3ReaderProxy {
    function read() external view returns (int224 value, uint32 timestamp);
}

contract MockApi3ReaderProxy is IApi3ReaderProxy {
    int224 public value;
    uint32 public timestamp;

    constructor(int224 _value, uint32 _timestamp) {
        value = _value;
        timestamp = _timestamp;
    }

    function read() external view override returns (int224, uint32) {
        return (value, timestamp);
    }

    function setValue(int224 _value) external {
        value = _value;
    }

    function setTimestamp(uint32 _timestamp) external {
        timestamp = _timestamp;
    }
}

contract MockRouter {
    using SafeERC20 for IERC20;

    function swapNativeForToken(address tokenOut, address receiver, uint256 amountOut) external payable {
        IERC20(tokenOut).safeTransfer(receiver, amountOut);
    }
}

contract WBTCMock is ERC20 {
    constructor() ERC20("Wrapped BTC", "WBTC") {}

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract Api3SwapAdapterSeiForkTest is Test {
    address internal constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    Api3SwapAdapter internal adapter;
    ERC20Mock internal tokenOut;
    MockRouter internal router;
    MockApi3ReaderProxy internal seiUsdProxy;
    MockApi3ReaderProxy internal wbtcUsdProxy;
    address internal owner;
    address internal vault;

    function setUp() public {
        owner = makeAddr("owner");
        vault = makeAddr("vault");

        // Create mock API3 price feeds
        // SEI-USD: $0.50 (18 decimals) = 0.5e18
        seiUsdProxy = new MockApi3ReaderProxy(int224(uint224(0.5e18)), uint32(block.timestamp));
        // WBTC-USD: $60,000 (8 decimals) = 60000e8
        wbtcUsdProxy = new MockApi3ReaderProxy(int224(uint224(60000e8)), uint32(block.timestamp));

        Api3SwapAdapter implementation = new Api3SwapAdapter();
        bytes memory initData = abi.encodeWithSelector(Api3SwapAdapter.initialize.selector, owner, vault);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        tokenOut = new ERC20Mock();
        router = new MockRouter();

        tokenOut.mint(address(router), 10_000_000e6);

        vm.startPrank(owner);
        adapter = Api3SwapAdapter(payable(address(proxy)));
        adapter.setWhitelistedRouter(address(router), true);
        adapter.setWhitelistedToken(NATIVE_TOKEN, true);
        adapter.setWhitelistedToken(address(tokenOut), true);
        adapter.setPriceFeed(NATIVE_TOKEN, address(seiUsdProxy), 18, 0);
        adapter.setPriceFeed(address(tokenOut), address(seiUsdProxy), 18, 0);
        vm.stopPrank();
    }

    function test_swapNativeForToken_SeiPriceValidation() public {
        uint256 amountIn = 1 ether;
        vm.deal(vault, amountIn);

        // Verify mock price feed is set up correctly
        (int224 value,) = seiUsdProxy.read();
        require(value > 0, "Invalid API3 price");

        uint16 bps = adapter.minReturnBps();
        // Since both tokens use the same price feed (SEI-USD), expected output equals input
        uint256 expectedOut18 = amountIn;
        uint256 minOut18 = expectedOut18 * uint256(bps) / 10_000;

        uint256 minOut = minOut18 / 1e12;
        uint256 amountOut = minOut + 1;

        bytes memory payload = abi.encodeWithSelector(
            MockRouter.swapNativeForToken.selector,
            address(tokenOut),
            address(adapter),
            amountOut
        );

        vm.prank(vault);
        adapter.execute{ value: amountIn }(
            address(router),
            NATIVE_TOKEN,
            address(tokenOut),
            amountIn,
            address(0),
            payload
        );

        assertEq(tokenOut.balanceOf(vault), amountOut);
        assertEq(address(adapter).balance, 0);
    }

    function test_swapNativeForToken_WbtcPriceValidation() public {
        // Create WBTC mock token with 8 decimals (WBTC standard)
        WBTCMock wbtc = new WBTCMock();
        wbtc.mint(address(router), 1000e8); // 1000 WBTC

        // Setup WBTC price feed (mock WBTC-USD proxy uses 8 decimals)
        vm.startPrank(owner);
        adapter.setWhitelistedToken(address(wbtc), true);
        adapter.setPriceFeed(address(wbtc), address(wbtcUsdProxy), 8, 0);
        vm.stopPrank();

        uint256 amountIn = 1 ether; // 1 SEI
        vm.deal(vault, amountIn);

        // Validate WBTC-USD price feed
        (int224 wbtcValue,) = wbtcUsdProxy.read();
        require(wbtcValue > 0, "Invalid WBTC-USD API3 price");

        // Validate SEI-USD price feed
        (int224 seiValue,) = seiUsdProxy.read();
        require(seiValue > 0, "Invalid SEI-USD API3 price");

        // Calculate expected output using price feeds
        // SEI price in USD (18 decimals from mock)
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 seiPrice18 = uint256(int256(seiValue));
        // WBTC price in USD (8 decimals from mock, will be scaled to 18 by adapter)
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 wbtcPrice8 = uint256(int256(wbtcValue));
        uint256 wbtcPrice18 = wbtcPrice8 * 1e10; // Scale to 18 decimals

        // Value in USD: amountIn (18 decimals) * seiPrice18 / 1e18
        uint256 valueUsd18 = (amountIn * seiPrice18) / 1e18;
        // Expected WBTC output (in 18 decimals): valueUsd18 * 1e18 / wbtcPrice18
        uint256 expectedOut18 = (valueUsd18 * 1e18) / wbtcPrice18;
        // Convert to WBTC decimals (8): expectedOut18 / 1e10
        uint256 expectedOut8 = expectedOut18 / 1e10;

        uint16 bps = adapter.minReturnBps();
        uint256 minOut8 = (expectedOut8 * uint256(bps)) / 10_000;
        uint256 amountOut = minOut8 > 0 ? minOut8 + 1 : 1;

        bytes memory payload = abi.encodeWithSelector(
            MockRouter.swapNativeForToken.selector,
            address(wbtc),
            address(adapter),
            amountOut
        );

        vm.prank(vault);
        adapter.execute{ value: amountIn }(
            address(router),
            NATIVE_TOKEN,
            address(wbtc),
            amountIn,
            address(0),
            payload
        );

        assertEq(wbtc.balanceOf(vault), amountOut);
        assertEq(address(adapter).balance, 0);
    }
}
