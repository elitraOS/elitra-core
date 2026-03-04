// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}

interface IApi3ReaderProxy {
    function read() external view returns (int224 value, uint32 timestamp);
}

/// @title Api3SwapAdapter
/// @notice Vault-facing adapter for arbitrary routers with API3 price validation.
/// @dev Uses post-swap balance deltas to validate received output against API3 oracle prices.
contract Api3SwapAdapter is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Pseudo-address for native token.
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice The vault that is allowed to use this adapter.
    address public vault;

    /// @notice Router whitelist.
    mapping(address router => bool isAllowed) public whitelistedRouters;
    bool public enforceRouterWhitelist;

    /// @notice Token whitelist.
    mapping(address token => bool isAllowed) public whitelistedTokens;
    bool public enforceTokenWhitelist;

    /// @notice Min return bps versus API3-implied output (0 = disabled).
    uint16 public minReturnBps;

    /// @notice Default max staleness for API3 answers (seconds).
    uint32 public defaultStaleSeconds;

    struct PriceFeedConfig {
        address proxy;
        uint8 decimals;
        uint32 staleSeconds;
    }

    mapping(address token => PriceFeedConfig) public priceFeeds;

    event PriceFeedSet(address indexed token, address indexed proxy, uint8 decimals, uint32 staleSeconds);
    event PriceFeedRemoved(address indexed token);
    event DefaultStaleSecondsSet(uint32 oldValue, uint32 newValue);

    error OnlyVault();
    error RouterNotAllowed(address router);
    error TokenNotAllowed(address token);
    error InvalidDstReceiver(address dstReceiver);
    error RouterCallFailed();
    error InvalidMinReturnBps(uint16 bps);
    error PriceFeedNotSet(address token);
    error InvalidPrice(address token);
    error PriceStale(address token, uint256 updatedAt, uint256 staleSeconds);
    error MinReturnNotMet(uint256 spentIn, uint256 receivedOut, uint256 expectedOut18, uint16 minBps);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the adapter with owner and vault addresses
    /// @param _owner Address that will own the adapter
    /// @param _vault Address of the vault that can use this adapter
    /// @dev Sets default values: minReturnBps = 9900 (99%), defaultStaleSeconds = 1 hour, whitelists enforced
    function initialize(address _owner, address _vault) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        _transferOwnership(_owner);
        vault = _vault;
        minReturnBps = 9900;
        defaultStaleSeconds = 1 hours;
        enforceRouterWhitelist = true;
        enforceTokenWhitelist = true;
    }

    modifier onlyVault() {
        if (vault == address(0)) revert OnlyVault();
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    // ============================ admin ============================

    /// @notice Enable or disable router whitelist enforcement
    /// @param enforce If true, only whitelisted routers can be used; if false, any router is allowed
    function setEnforceRouterWhitelist(bool enforce) external onlyOwner {
        enforceRouterWhitelist = enforce;
    }

    /// @notice Add or remove a router from the whitelist
    /// @param router Address of the router to whitelist/unwhitelist
    /// @param isAllowed True to allow the router, false to disallow
    function setWhitelistedRouter(address router, bool isAllowed) external onlyOwner {
        whitelistedRouters[router] = isAllowed;
    }

    /// @notice Enable or disable token whitelist enforcement
    /// @param enforce If true, only whitelisted tokens can be used; if false, any token is allowed
    function setEnforceTokenWhitelist(bool enforce) external onlyOwner {
        enforceTokenWhitelist = enforce;
    }

    /// @notice Add or remove a token from the whitelist
    /// @param token Address of the token to whitelist/unwhitelist
    /// @param isAllowed True to allow the token, false to disallow
    function setWhitelistedToken(address token, bool isAllowed) external onlyOwner {
        whitelistedTokens[token] = isAllowed;
    }

    /// @notice Set the minimum return basis points for swap validation
    /// @param bps Minimum return in basis points (10000 = 100%, 9900 = 99%). Set to 0 to disable validation
    /// @dev Reverts if bps > 10000. The adapter will validate that received output >= expected * bps / 10000
    function setMinReturnBps(uint16 bps) external onlyOwner {
        if (bps > 10_000) revert InvalidMinReturnBps(bps);
        minReturnBps = bps;
    }

    /// @notice Set the default maximum staleness for API3 price feeds
    /// @param newValue Maximum age in seconds before a price is considered stale (0 = no staleness check)
    /// @dev This is used as the default when a price feed doesn't specify its own staleSeconds
    function setDefaultStaleSeconds(uint32 newValue) external onlyOwner {
        emit DefaultStaleSecondsSet(defaultStaleSeconds, newValue);
        defaultStaleSeconds = newValue;
    }

    /// @notice Set or update the API3 price feed configuration for a token
    /// @param token Address of the token (or NATIVE_TOKEN for native currency)
    /// @param proxy Address of the API3 reader proxy contract
    /// @param decimals Number of decimals in the price feed (typically 8 or 18)
    /// @param staleSeconds Maximum age in seconds before price is considered stale (0 = use defaultStaleSeconds)
    /// @dev Reverts if proxy is zero address
    function setPriceFeed(address token, address proxy, uint8 decimals, uint32 staleSeconds) external onlyOwner {
        if (proxy == address(0)) revert PriceFeedNotSet(token);
        priceFeeds[token] = PriceFeedConfig({ proxy: proxy, decimals: decimals, staleSeconds: staleSeconds });
        emit PriceFeedSet(token, proxy, decimals, staleSeconds);
    }

    /// @notice Remove the price feed configuration for a token
    /// @param token Address of the token to remove the price feed for
    /// @dev After removal, swaps involving this token will fail price validation
    function removePriceFeed(address token) external onlyOwner {
        delete priceFeeds[token];
        emit PriceFeedRemoved(token);
    }

    /// @notice Approve a router to spend this adapter's tokens (for when tokens accumulate here)
    /// @param router Address of the router to approve
    /// @param token Address of the token to approve
    /// @param amount Amount to approve (use type(uint256).max for unlimited)
    /// @dev This is useful when tokens accumulate in the adapter and need to be spent by a router
    function approveRouter(address router, address token, uint256 amount) external onlyOwner {
        IERC20(token).approve(router, amount);
    }

    // ============================ actions ============================

    /// @notice Execute a swap by forwarding calldata to a router and validating output using API3
    /// @param router The router address to call
    /// @param tokenIn The token spent (or NATIVE_TOKEN for native currency)
    /// @param tokenOut The token received (or NATIVE_TOKEN for native currency)
    /// @param amountIn The intended input amount for the swap
    /// @param dstReceiver The intended receiver of the output (address(0) treated as this adapter)
    /// @param payload Full calldata for the router call
    /// @return routerReturn Return value from the router call
    /// @dev Validates router, tokens, and receiver before executing. Validates output against API3 prices after execution
    function execute(
        address router,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address dstReceiver,
        bytes calldata payload
    ) external payable onlyVault returns (bytes memory routerReturn) {
        _validateRouter(router);
        _validateTokens(tokenIn, tokenOut);
        _validateDstReceiver(dstReceiver);

        address receiver = dstReceiver == address(0) ? address(this) : dstReceiver;

        if (tokenIn != NATIVE_TOKEN) {
            _pullFromVault(tokenIn, amountIn);
            IERC20(tokenIn).forceApprove(router, amountIn);
        }

        uint256 srcBalanceBefore = _getBalance(tokenIn, address(this));
        uint256 dstBalanceBefore = _getBalance(tokenOut, receiver);

        (bool ok, bytes memory ret) = router.call{ value: msg.value }(payload);
        if (!ok) revert RouterCallFailed();
        routerReturn = ret;

        if (tokenIn != NATIVE_TOKEN) {
            IERC20(tokenIn).forceApprove(router, 0);
        }

        uint256 srcBalanceAfter = _getBalance(tokenIn, address(this));
        uint256 dstBalanceAfter = _getBalance(tokenOut, receiver);

        uint256 spentIn = srcBalanceBefore > srcBalanceAfter ? (srcBalanceBefore - srcBalanceAfter) : 0;
        uint256 receivedOut = dstBalanceAfter > dstBalanceBefore ? (dstBalanceAfter - dstBalanceBefore) : 0;

        _postValidateMinReturn(spentIn, receivedOut, tokenIn, tokenOut);

        _sweep(tokenIn);
        _sweep(tokenOut);
    }

    // ============================ internal ============================

    function _validateRouter(address router) internal view {
        if (enforceRouterWhitelist && !whitelistedRouters[router]) revert RouterNotAllowed(router);
    }

    function _validateTokens(address tokenIn, address tokenOut) internal view {
        if (!enforceTokenWhitelist) return;
        if (!whitelistedTokens[tokenIn]) revert TokenNotAllowed(tokenIn);
        if (!whitelistedTokens[tokenOut]) revert TokenNotAllowed(tokenOut);
    }

    function _validateDstReceiver(address dstReceiver) internal view {
        if (dstReceiver != address(0) && dstReceiver != address(this) && dstReceiver != vault) {
            revert InvalidDstReceiver(dstReceiver);
        }
    }

    function _postValidateMinReturn(uint256 spentIn, uint256 receivedOut, address tokenIn, address tokenOut)
        internal
        view
    {
        uint16 bps = minReturnBps;
        if (bps == 0) return;

        uint256 in18 = _to18(spentIn, _decimals(tokenIn));
        uint256 out18 = _to18(receivedOut, _decimals(tokenOut));

        uint256 priceIn = _price18(tokenIn);
        uint256 priceOut = _price18(tokenOut);

        uint256 valueUsd18 = Math.mulDiv(in18, priceIn, 1e18);
        uint256 expectedOut18 = Math.mulDiv(valueUsd18, 1e18, priceOut);

        if (out18 * 10_000 < expectedOut18 * uint256(bps)) {
            revert MinReturnNotMet(spentIn, receivedOut, expectedOut18, bps);
        }
    }

    function _price18(address token) internal view returns (uint256) {
        PriceFeedConfig memory cfg = priceFeeds[token];
        if (cfg.proxy == address(0)) revert PriceFeedNotSet(token);

        (int224 value, uint32 updatedAt) = IApi3ReaderProxy(cfg.proxy).read();
        if (value <= 0) revert InvalidPrice(token);

        uint32 staleSeconds = cfg.staleSeconds == 0 ? defaultStaleSeconds : cfg.staleSeconds;
        if (staleSeconds != 0 && uint256(updatedAt) + staleSeconds < block.timestamp) {
            revert PriceStale(token, uint256(updatedAt), staleSeconds);
        }   

        if (value < 0) revert InvalidPrice(token);

        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 price = uint256(int256(value));
        if (cfg.decimals == 18) return price;
        if (cfg.decimals < 18) return price * (10 ** (18 - cfg.decimals));
        return price / (10 ** (cfg.decimals - 18));
    }

    function _getBalance(address token, address account) internal view returns (uint256) {
        if (token == NATIVE_TOKEN) {
            return account.balance;
        }
        return IERC20(token).balanceOf(account);
    }

    function _pullFromVault(address token, uint256 amount) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal >= amount) return;
        IERC20(token).safeTransferFrom(vault, address(this), amount - bal);
    }

    function _transfer(address token, address to, uint256 amount) internal {
        if (token == NATIVE_TOKEN) {
            (bool success,) = to.call{ value: amount }("");
            require(success, "Native transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function _sweep(address token) internal {
        uint256 bal = _getBalance(token, address(this));
        if (bal > 0) _transfer(token, vault, bal);
    }

    function _decimals(address token) internal view returns (uint8) {
        if (token == NATIVE_TOKEN) return 18;
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }

    function _to18(uint256 amount, uint8 tokenDecimals) internal pure returns (uint256) {
        if (tokenDecimals == 18) return amount;
        if (tokenDecimals < 18) return amount * (10 ** (18 - tokenDecimals));
        return amount / (10 ** (tokenDecimals - 18));
    }

    /// @notice Allow adapter to receive native token
    /// @dev Required for swaps that involve native currency
    receive() external payable {}

    /// @dev Authorize upgrade to new implementation (UUPS pattern)
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
