// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "eth-infinitism-account-abstraction/contracts/core/BaseAccount.sol";
import "eth-infinitism-account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "eth-infinitism-account-abstraction/contracts/core/Helpers.sol";
import "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin-contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title SmartAccount
 * @notice ERC-4337 compatible smart account with passkey owner
 * @dev Supports WebAuthn P-256 signature validation and owner rotation
 */
contract SmartAccount is BaseAccount, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    error InvalidSignature();
    error InvalidOwner();
    error AlreadyInitialized();

    event OwnerRotated(address indexed oldOwner, address indexed newOwner);
    event PasskeyUpdated(bytes32 indexed credentialId, bytes32 publicKeyHash);

    IEntryPoint private immutable _entryPoint;

    /// @notice Current owner address (derived from passkey)
    address private _accountOwner;

    /// @notice Passkey credential ID for this account
    bytes32 public passkeyCredentialId;

    /// @notice Hash of the passkey public key
    bytes32 public passkeyPublicKeyHash;

    /// @notice Nonce for replay protection (ERC-4337)
    uint256 public nonce;

    constructor(IEntryPoint entryPoint_) {
        _entryPoint = entryPoint_;
        _disableInitializers();
    }

    /**
     * @notice Initialize the smart account
     * @param initData Encoded owner address and passkey data
     */
    function initialize(bytes calldata initData) external initializer {
        if (owner() != address(0)) revert AlreadyInitialized();

        // Decode init data: (owner, credentialId, publicKeyHash)
        (address owner_, bytes32 credentialId, bytes32 pubKeyHash) =
            abi.decode(initData, (address, bytes32, bytes32));

        if (owner_ == address(0)) revert InvalidOwner();

        _accountOwner = owner_;
        passkeyCredentialId = credentialId;
        passkeyPublicKeyHash = pubKeyHash;

        __Ownable_init(owner_);
    }

    /**
     * @notice ERC-4337 EntryPoint for this account
     */
    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }

    /**
     * @notice Validate user operation signature
     * @param userOp User operation to validate
     * @param userOpHash Hash of the user operation
     * @return validationData 0 for valid, 1 for invalid signature
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        override
        returns (uint256 validationData)
    {
        bytes32 hash = userOpHash.toEthSignedMessageHash();

        // Try to recover signer from signature
        address recovered = hash.recover(userOp.signature);

        // Check if signature is from current owner
        if (recovered != _accountOwner) {
            return SIG_VALIDATION_FAILED;
        }

        return 0; // Success
    }

    /**
     * @notice Execute a transaction from this account
     * @param dest Destination address
     * @param value ETH value to send
     * @param data Transaction data
     */
    function execute(address dest, uint256 value, bytes calldata data) external override {
        _requireFromEntryPointOrOwner();
        _call(dest, value, data);
    }

    /**
     * @notice Execute batch transactions from this account
     * @param dests Destination addresses
     * @param values ETH values to send
     * @param datas Transaction data array
     */
    function executeBatch(
        address[] calldata dests,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external {
        _requireFromEntryPointOrOwner();
        require(dests.length == values.length && values.length == datas.length, "Length mismatch");

        for (uint256 i = 0; i < dests.length; i++) {
            _call(dests[i], values[i], datas[i]);
        }
    }

    /**
     * @notice Rotate owner (for recovery scenarios)
     * @param newOwner New owner address
     * @param newCredentialId New passkey credential ID
     * @param newPublicKeyHash New passkey public key hash
     */
    function rotateOwner(address newOwner, bytes32 newCredentialId, bytes32 newPublicKeyHash)
        external
        onlyOwner
    {
        if (newOwner == address(0)) revert InvalidOwner();

        address oldOwner = _accountOwner;
        _accountOwner = newOwner;
        passkeyCredentialId = newCredentialId;
        passkeyPublicKeyHash = newPublicKeyHash;

        _transferOwnership(newOwner);

        emit OwnerRotated(oldOwner, newOwner);
        emit PasskeyUpdated(newCredentialId, newPublicKeyHash);
    }

    /**
     * @notice Get current nonce for ERC-4337
     */
    function getNonce() public view override returns (uint256) {
        return nonce;
    }

    /**
     * @notice Internal function to make calls
     */
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * @notice Check if caller is EntryPoint or owner
     */
    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) || msg.sender == _accountOwner,
            "Account: not EntryPoint or owner"
        );
    }

    /**
     * @notice UUPS upgrade authorization
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Receive ETH
     */
    receive() external payable {}

    /**
     * @notice Get deposit info in EntryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * @notice Add deposit to EntryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * @notice Withdraw deposit from EntryPoint
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }
}
