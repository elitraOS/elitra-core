// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { Authority } from "@solmate/auth/Auth.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AuthUpgradeable
 * @author Elitra
 * @notice Upgradable version of Solmate's Auth contract for access control
 * @dev Fork of https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol
 *
 * @dev This contract provides a flexible authorization system where:
 *      - There is a single owner who has full authority
 *      - An optional Authority contract can be used to delegate permissions
 *      - The Authority contract can define fine-grained access control rules
 *
 * @dev Uses ERC-7201 storage pattern for upgradeability compatibility
 */
abstract contract AuthUpgradeable is Initializable {
    /// @notice Emitted when ownership is transferred
    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /// @notice Emitted when the Authority contract is updated
    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    /// @custom:storage-location erc7201:auth.storage
    /// @dev Storage slot for AuthUpgradeable state, using ERC-7201 namespace
    struct AuthStorage {
        /// @notice Address of the contract owner (has full authority)
        address owner;
        /// @notice Optional Authority contract for delegated access control
        Authority authority;
    }

    /// @notice Storage slot location computed from ERC-7201 namespace "auth.storage"
    /// @dev keccak256(abi.encode(uint256(keccak256("auth.storage")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant AuthStorageLocation = 0xdd3fd67aef415aded9493b31ad20a02d2991d4bb2760431cc729821271eaea00;

    /**
     * @notice Retrieves the AuthStorage struct from the designated storage slot
     * @return $ Storage pointer to the AuthStorage struct
     * @dev Uses inline assembly to access the storage slot directly
     */
    function _getAuthStorage() private pure returns (AuthStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := AuthStorageLocation
        }
    }

    /**
     * @notice Initializes the Auth module with owner and authority
     * @dev Must be called during contract initialization
     * @param _owner Address that will own this contract (has full authority)
     * @param _authority Optional Authority contract for delegated access control
     *
     * @dev The Authority contract can define custom rules for who can call what functions.
     *      If set to address(0), only the owner has authority.
     */
    function __Auth_init(address _owner, Authority _authority) internal onlyInitializing {
        AuthStorage storage $ = _getAuthStorage();
        $.owner = _owner;
        $.authority = _authority;
        emit OwnershipTransferred(msg.sender, _owner);
        emit AuthorityUpdated(msg.sender, _authority);
    }

    /**
     * @notice Modifier that restricts function access to authorized users
     * @dev Reverts if neither the owner nor the Authority contract grants permission
     */
    modifier requiresAuth() virtual {
        require(isAuthorized(msg.sender, msg.sig), "UNAUTHORIZED");

        _;
    }

    /**
     * @notice Checks if a user is authorized to call a function
     * @param user Address to check authorization for
     * @param functionSig Function selector (4 bytes) being called
     * @return True if the user is authorized, false otherwise
     *
     * @dev Authorization logic:
     *      1. If Authority contract is set, check if it authorizes the user
     *      2. Owner is always authorized regardless of Authority contract
     */
    function isAuthorized(address user, bytes4 functionSig) public view virtual returns (bool) {
        AuthStorage storage $ = _getAuthStorage();
        Authority auth = $.authority;
        return (address(auth) != address(0) && auth.canCall(user, address(this), functionSig)) || user == $.owner;
    }

    /**
     * @notice Gets the current owner address
     * @return Address of the contract owner
     */
    function owner() public view virtual returns (address) {
        return _getAuthStorage().owner;
    }

    /**
     * @notice Gets the current Authority contract address
     * @return Address of the Authority contract (may be address(0))
     */
    function authority() public view virtual returns (Authority) {
        return _getAuthStorage().authority;
    }

    /**
     * @notice Sets a new Authority contract
     * @dev Only the owner or current Authority can call this
     * @param newAuthority New Authority contract address (use address(0) to disable)
     *
     * @dev This check is ordered (owner first) to ensure the owner can always swap
     *      the Authority even if it's reverting or using excessive gas.
     */
    function setAuthority(Authority newAuthority) public virtual {
        AuthStorage storage $ = _getAuthStorage();
        // We check if the caller is the owner first because we want to ensure they can
        // always swap out the authority even if it's reverting or using up a lot of gas.
        // solhint-disable-next-line reason-string
        require(msg.sender == $.owner || $.authority.canCall(msg.sender, address(this), msg.sig), "UNAUTHORIZED");

        $.authority = newAuthority;

        emit AuthorityUpdated(msg.sender, newAuthority);
    }

    /**
     * @notice Transfers ownership to a new address
     * @dev Only authorized users (owner or Authority) can call this
     * @param newOwner Address to transfer ownership to
     *
     * @dev The new owner will have full authority over the contract.
     *      Use address(0) to renounce ownership (not recommended).
     */
    function transferOwnership(address newOwner) public virtual requiresAuth {
        AuthStorage storage $ = _getAuthStorage();
        $.owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }
}
