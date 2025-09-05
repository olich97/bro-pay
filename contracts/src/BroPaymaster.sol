// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "eth-infinitism-account-abstraction/contracts/interfaces/IPaymaster.sol";
import "eth-infinitism-account-abstraction/contracts/core/BasePaymaster.sol";
import "eth-infinitism-account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "eth-infinitism-account-abstraction/contracts/core/Helpers.sol";
import "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";

import "./TimelockedUUPS.sol";

interface IBroPaymaster {
    function setPolicy(bytes calldata policy) external;
    function sponsor(bytes calldata userOp, bytes calldata attestation) external returns (bool);
}

/**
 * @title BroPaymaster
 * @notice Enhanced ERC-4337 Paymaster with policy engine and device attestation
 * @dev Sponsors gas for whitelisted users/operations with policy validation
 */
contract BroPaymaster is IPaymaster, TimelockedUUPS, IBroPaymaster {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    error PolicyViolation();
    error UserNotWhitelisted();
    error DailyLimitExceeded();
    error InvalidAttestation();
    error InsufficientDeposit();

    event PolicyUpdated(bytes32 indexed policyHash);
    event UserSponsored(address indexed user, uint256 actualGasCost);
    event AttestationValidated(address indexed user, bytes32 attestationHash);

    /// @notice Maximum gas per sponsored operation
    uint256 public maxGasPerOp = 300_000;

    /// @notice Maximum daily gas spend per user (in wei)
    uint256 public maxDailyGasPerUser = 0.01 ether;

    /// @notice Policy hash for validation rules
    bytes32 public policyHash;

    /// @notice Whitelisted users who can get sponsored
    mapping(address => bool) public whitelistedUsers;

    /// @notice Daily gas spend tracking per user
    mapping(address => uint256) public dailyGasSpent;
    mapping(address => uint256) public lastSpendDay;

    /// @notice Device attestation validator
    address public attestationValidator;

    /// @notice Minimum deposit required for sponsorship
    uint256 public minDepositRequired = 0.1 ether;

    /// @notice EntryPoint contract
    IEntryPoint public entryPoint;

    /**
     * @custom:oz-upgrades-unsafe-allow constructor *
     */
    constructor() {
        _disableInitializers();
    }

    function initialize(IEntryPoint ep, address owner_, address attestationValidator_)
        public
        initializer
    {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        entryPoint = ep;
        attestationValidator = attestationValidator_;
    }

    /* -------------------------------------------------------------------- */
    /* IPaymaster implementation                                            */
    /* -------------------------------------------------------------------- */

    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        require(msg.sender == address(entryPoint), "Only EntryPoint can call");
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external {
        require(msg.sender == address(entryPoint), "Only EntryPoint can call");
        _postOp(mode, context, actualGasCost);
    }

    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) internal view returns (bytes memory context, uint256 validationData) {
        // Basic gas limit check
        if (maxCost > maxGasPerOp * tx.gasprice) {
            return ("", SIG_VALIDATION_FAILED);
        }

        // Check if paymaster has sufficient deposit
        if (getDeposit() < minDepositRequired) {
            return ("", SIG_VALIDATION_FAILED);
        }

        // Extract sender from userOp
        address sender = userOp.sender;

        // Check if user is whitelisted
        if (!whitelistedUsers[sender]) {
            return ("", SIG_VALIDATION_FAILED);
        }

        // Check daily spending limit
        uint256 today = block.timestamp / 1 days;
        uint256 currentDailySpent = (lastSpendDay[sender] == today) ? dailyGasSpent[sender] : 0;

        if (currentDailySpent + maxCost > maxDailyGasPerUser) {
            return ("", SIG_VALIDATION_FAILED);
        }

        // For PoC: skip device attestation validation in paymasterAndData
        // Production: validate device attestation from userOp.paymasterAndData

        // Pack context for post-op
        context = abi.encode(sender, maxCost, today);

        return (context, 0); // Success
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal {
        if (mode == PostOpMode.postOpReverted) {
            return; // Don't update on revert
        }

        // Unpack context
        (address sender, uint256 maxCost, uint256 today) =
            abi.decode(context, (address, uint256, uint256));

        // Update daily spending tracking
        if (lastSpendDay[sender] != today) {
            dailyGasSpent[sender] = 0;
            lastSpendDay[sender] = today;
        }

        dailyGasSpent[sender] += actualGasCost;

        emit UserSponsored(sender, actualGasCost);
    }

    /* -------------------------------------------------------------------- */
    /* Policy Management                                                    */
    /* -------------------------------------------------------------------- */

    /**
     * @notice Set sponsorship policy (owner only)
     * @param policy Encoded policy rules
     */
    function setPolicy(bytes calldata policy) external override onlyOwner {
        policyHash = keccak256(policy);
        emit PolicyUpdated(policyHash);
    }

    /**
     * @notice Check if operation should be sponsored
     * @param userOp Encoded user operation
     * @param attestation Device attestation data
     * @return shouldSponsor True if operation should be sponsored
     */
    function sponsor(bytes calldata userOp, bytes calldata attestation)
        external
        view
        override
        returns (bool shouldSponsor)
    {
        // For PoC: simplified sponsorship logic
        // Production: implement full policy engine

        // Decode basic userOp data
        // This would be more complex in production
        return true; // PoC: sponsor all for now
    }

    /* -------------------------------------------------------------------- */
    /* User Management                                                      */
    /* -------------------------------------------------------------------- */

    /**
     * @notice Add users to whitelist (owner only)
     * @param users Array of user addresses to whitelist
     */
    function addToWhitelist(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whitelistedUsers[users[i]] = true;
        }
    }

    /**
     * @notice Remove users from whitelist (owner only)
     * @param users Array of user addresses to remove
     */
    function removeFromWhitelist(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whitelistedUsers[users[i]] = false;
        }
    }

    /**
     * @notice Check if user is whitelisted
     * @param user User address to check
     * @return isWhitelisted True if user is whitelisted
     */
    function isUserWhitelisted(address user) external view returns (bool isWhitelisted) {
        return whitelistedUsers[user];
    }

    /**
     * @notice Get user's daily gas spent
     * @param user User address
     * @return spent Amount spent today in wei
     * @return remaining Amount remaining today in wei
     */
    function getDailyGasSpent(address user)
        external
        view
        returns (uint256 spent, uint256 remaining)
    {
        uint256 today = block.timestamp / 1 days;
        spent = (lastSpendDay[user] == today) ? dailyGasSpent[user] : 0;
        remaining = (spent < maxDailyGasPerUser) ? maxDailyGasPerUser - spent : 0;
    }

    /* -------------------------------------------------------------------- */
    /* Admin Functions                                                      */
    /* -------------------------------------------------------------------- */

    function setMaxGasPerOp(uint256 newLimit) external onlyOwner {
        maxGasPerOp = newLimit;
    }

    function setMaxDailyGasPerUser(uint256 newLimit) external onlyOwner {
        maxDailyGasPerUser = newLimit;
    }

    function setMinDepositRequired(uint256 newMin) external onlyOwner {
        minDepositRequired = newMin;
    }

    function setAttestationValidator(address newValidator) external onlyOwner {
        attestationValidator = newValidator;
    }

    /**
     * @notice Get current paymaster deposit
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    /**
     * @notice Add deposit to EntryPoint
     */
    function addDeposit() external payable onlyOwner {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    /**
     * @notice Withdraw deposit from EntryPoint
     */
    function withdrawDeposit(address payable withdrawAddress, uint256 amount) external onlyOwner {
        entryPoint.withdrawTo(withdrawAddress, amount);
    }

    /**
     * @notice Fund paymaster via direct transfer
     */
    receive() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    // Test helper function - remove in production
    function testValidatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external view returns (bytes memory context, uint256 validationData) {
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }
}
