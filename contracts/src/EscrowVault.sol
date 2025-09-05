// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "./TimelockedUUPS.sol";

interface IEscrowVault {
    struct Intent {
        address sender;
        bytes32 recipHash;
        uint256 amount;
        uint64 createdAt;
        uint64 expiry;
        bool released;
        bool revoked;
    }

    function create(
        bytes32 intentId,
        address sender,
        bytes32 recipHash,
        uint256 amount,
        uint64 expiry
    ) external;
    function release(bytes32 intentId, address recipientAccount, bytes calldata recipProof)
        external;
    function revoke(bytes32 intentId) external;
    function refund(bytes32 intentId) external;

    event EscrowFunded(bytes32 indexed intentId, address indexed sender, uint256 amount);
    event EscrowReleased(bytes32 indexed intentId, address indexed recipient, uint256 amount);
    event EscrowRevoked(bytes32 indexed intentId);
    event EscrowRefunded(bytes32 indexed intentId);
}

/**
 * @title EscrowVault
 * @notice Holds USDC per Payment Intent with recipient binding & timers
 * @dev Enforces phone hash binding and undo/expiry mechanics
 */
contract EscrowVault is IEscrowVault, Initializable, ReentrancyGuardUpgradeable, TimelockedUUPS {
    using SafeERC20 for IERC20;

    error IntentNotFound();
    error IntentAlreadyExists();
    error IntentExpired();
    error IntentAlreadyReleased();
    error IntentAlreadyRevoked();
    error UnauthorizedSender();
    error UnauthorizedRecipient();
    error InvalidRecipientProof();
    error RevokeWindowExpired();
    error RefundNotAvailable();
    error InvalidAmount();
    error InvalidExpiry();

    /// @notice USDC token contract
    IERC20 public token;

    /// @notice Proof signer address (backend service)
    address public proofSigner;

    /// @notice Default revoke window (10 minutes)
    uint64 public constant DEFAULT_REVOKE_WINDOW = 600;

    /// @notice Maximum expiry duration (30 days)
    uint64 public constant MAX_EXPIRY_DURATION = 30 days;

    /// @notice Payment intents storage
    mapping(bytes32 => Intent) public intents;

    /// @notice Intent existence check
    mapping(bytes32 => bool) public intentExists;

    /// @notice Total escrowed amount per user
    mapping(address => uint256) public totalEscrowed;

    /**
     * @custom:oz-upgrades-unsafe-allow constructor *
     */
    constructor() {
        _disableInitializers();
    }

    function initialize(address token_, address proofSigner_, address owner_) public initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        token = IERC20(token_);
        proofSigner = proofSigner_;
    }

    /**
     * @notice Create a new Payment Intent with escrow
     * @param intentId Unique identifier for this intent
     * @param sender Address funding the escrow
     * @param recipHash Hash of recipient's phone number
     * @param amount USDC amount to escrow
     * @param expiry Unix timestamp when intent expires
     */
    function create(
        bytes32 intentId,
        address sender,
        bytes32 recipHash,
        uint256 amount,
        uint64 expiry
    ) external override nonReentrant {
        if (intentExists[intentId]) revert IntentAlreadyExists();
        if (amount == 0) revert InvalidAmount();
        if (expiry <= block.timestamp) revert InvalidExpiry();
        if (expiry > block.timestamp + MAX_EXPIRY_DURATION) revert InvalidExpiry();

        // Transfer USDC from sender to vault
        token.safeTransferFrom(sender, address(this), amount);

        // Store intent
        intents[intentId] = Intent({
            sender: sender,
            recipHash: recipHash,
            amount: amount,
            createdAt: uint64(block.timestamp),
            expiry: expiry,
            released: false,
            revoked: false
        });

        intentExists[intentId] = true;
        totalEscrowed[sender] += amount;

        emit EscrowFunded(intentId, sender, amount);
    }

    /**
     * @notice Release escrow to recipient with valid proof
     * @param intentId Intent to release
     * @param recipientAccount Smart account address of recipient
     * @param recipProof Signed proof binding phoneHash to recipient account
     */
    function release(bytes32 intentId, address recipientAccount, bytes calldata recipProof)
        external
        override
        nonReentrant
    {
        Intent storage intent = intents[intentId];

        if (!intentExists[intentId]) revert IntentNotFound();
        if (intent.released) revert IntentAlreadyReleased();
        if (intent.revoked) revert IntentAlreadyRevoked();
        if (block.timestamp > intent.expiry) revert IntentExpired();

        // Verify recipient proof
        if (!_verifyRecipientProof(intentId, intent.recipHash, recipientAccount, recipProof)) {
            revert InvalidRecipientProof();
        }

        // Mark as released
        intent.released = true;
        totalEscrowed[intent.sender] -= intent.amount;

        // Transfer USDC to recipient
        token.safeTransfer(recipientAccount, intent.amount);

        emit EscrowReleased(intentId, recipientAccount, intent.amount);
    }

    /**
     * @notice Revoke intent by sender within revoke window
     * @param intentId Intent to revoke
     */
    function revoke(bytes32 intentId) external override nonReentrant {
        Intent storage intent = intents[intentId];

        if (!intentExists[intentId]) revert IntentNotFound();
        if (intent.released) revert IntentAlreadyReleased();
        if (intent.revoked) revert IntentAlreadyRevoked();
        if (msg.sender != intent.sender) revert UnauthorizedSender();

        // Check revoke window (10 minutes by default)
        if (block.timestamp > intent.createdAt + DEFAULT_REVOKE_WINDOW) {
            revert RevokeWindowExpired();
        }

        // Mark as revoked
        intent.revoked = true;
        totalEscrowed[intent.sender] -= intent.amount;

        // Return USDC to sender
        token.safeTransfer(intent.sender, intent.amount);

        emit EscrowRevoked(intentId);
    }

    /**
     * @notice Refund expired intent (anyone can trigger)
     * @param intentId Intent to refund
     */
    function refund(bytes32 intentId) external override nonReentrant {
        Intent storage intent = intents[intentId];

        if (!intentExists[intentId]) revert IntentNotFound();
        if (intent.released) revert IntentAlreadyReleased();
        if (intent.revoked) revert IntentAlreadyRevoked();
        if (block.timestamp <= intent.expiry) revert RefundNotAvailable();

        // Mark as revoked (effectively same as revoke)
        intent.revoked = true;
        totalEscrowed[intent.sender] -= intent.amount;

        // Return USDC to sender
        token.safeTransfer(intent.sender, intent.amount);

        emit EscrowRefunded(intentId);
    }

    /**
     * @notice Get intent details
     * @param intentId Intent identifier
     * @return Intent struct
     */
    function getIntent(bytes32 intentId) external view returns (Intent memory) {
        if (!intentExists[intentId]) revert IntentNotFound();
        return intents[intentId];
    }

    /**
     * @notice Check if intent can be released
     * @param intentId Intent identifier
     * @return canRelease True if intent can be released
     */
    function canRelease(bytes32 intentId) external view returns (bool) {
        if (!intentExists[intentId]) return false;

        Intent storage intent = intents[intentId];
        return !intent.released && !intent.revoked && block.timestamp <= intent.expiry;
    }

    /**
     * @notice Check if intent can be revoked by sender
     * @param intentId Intent identifier
     * @return canRevoke True if intent can be revoked
     */
    function canRevoke(bytes32 intentId) external view returns (bool) {
        if (!intentExists[intentId]) return false;

        Intent storage intent = intents[intentId];
        return !intent.released && !intent.revoked
            && block.timestamp <= intent.createdAt + DEFAULT_REVOKE_WINDOW;
    }

    /**
     * @notice Check if intent can be refunded
     * @param intentId Intent identifier
     * @return canRefund True if intent can be refunded
     */
    function canRefund(bytes32 intentId) external view returns (bool) {
        if (!intentExists[intentId]) return false;

        Intent storage intent = intents[intentId];
        return !intent.released && !intent.revoked && block.timestamp > intent.expiry;
    }

    /**
     * @notice Update proof signer (owner only)
     * @param newProofSigner New proof signer address
     */
    function setProofSigner(address newProofSigner) external onlyOwner {
        proofSigner = newProofSigner;
    }

    /**
     * @notice Emergency withdrawal (owner only)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }

    /**
     * @dev Verify recipient proof signature
     * @param intentId Intent identifier
     * @param recipHash Expected recipient phone hash
     * @param recipientAccount Claimed recipient account
     * @param recipProof Signature proof
     * @return valid True if proof is valid
     */
    function _verifyRecipientProof(
        bytes32 intentId,
        bytes32 recipHash,
        address recipientAccount,
        bytes calldata recipProof
    ) internal view returns (bool valid) {
        // For PoC: simplified signature verification
        // Production: implement full cryptographic proof verification

        // Construct message hash
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(intentId, recipHash, recipientAccount))
            )
        );

        // Extract signature components (r, s, v)
        if (recipProof.length != 65) return false;

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(add(recipProof.offset, 0x00))
            s := calldataload(add(recipProof.offset, 0x20))
            v := byte(0, calldataload(add(recipProof.offset, 0x40)))
        }

        // Recover signer
        address recovered = ecrecover(messageHash, v, r, s);

        // Check if signed by proof signer
        return recovered == proofSigner;
    }
}
