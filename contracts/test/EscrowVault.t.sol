// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "@openzeppelin-contracts/token/ERC20/ERC20.sol";

import "../src/EscrowVault.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract EscrowVaultTest is Test {
    EscrowVault public vault;
    MockERC20 public token;

    address public owner;
    address public proofSigner;
    address public sender;
    address public recipient;
    address public nonOwner;

    bytes32 public constant PHONE_HASH_1 = keccak256("phone1");
    bytes32 public constant PHONE_HASH_2 = keccak256("phone2");
    bytes32 public constant INTENT_ID_1 = keccak256("intent1");
    bytes32 public constant INTENT_ID_2 = keccak256("intent2");

    uint256 public constant AMOUNT = 100 * 10 ** 6; // 100 USDC
    uint64 public constant EXPIRY_DURATION = 86400; // 1 day

    event EscrowFunded(bytes32 indexed intentId, address indexed sender, uint256 amount);
    event EscrowReleased(bytes32 indexed intentId, address indexed recipient, uint256 amount);
    event EscrowRevoked(bytes32 indexed intentId);
    event EscrowRefunded(bytes32 indexed intentId);

    function setUp() public {
        owner = makeAddr("owner");
        proofSigner = makeAddr("proofSigner");
        sender = makeAddr("sender");
        recipient = makeAddr("recipient");
        nonOwner = makeAddr("nonOwner");

        // Deploy mock USDC
        token = new MockERC20();

        // Deploy EscrowVault
        vm.startPrank(owner);
        vault = EscrowVault(
            Upgrades.deployUUPSProxy(
                "EscrowVault",
                abi.encodeCall(EscrowVault.initialize, (address(token), proofSigner, owner))
            )
        );
        vm.stopPrank();

        // Setup test tokens
        token.mint(sender, AMOUNT * 10); // Give sender some tokens
        vm.prank(sender);
        token.approve(address(vault), type(uint256).max);
    }

    function testInitialize() public {
        assertEq(address(vault.token()), address(token));
        assertEq(vault.proofSigner(), proofSigner);
        assertEq(vault.owner(), owner);
    }

    function testCreateIntent() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.expectEmit(true, true, false, true);
        emit EscrowFunded(INTENT_ID_1, sender, AMOUNT);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        IEscrowVault.Intent memory intent = vault.getIntent(INTENT_ID_1);
        assertEq(intent.sender, sender);
        assertEq(intent.recipHash, PHONE_HASH_1);
        assertEq(intent.amount, AMOUNT);
        assertEq(intent.expiry, expiry);
        assertFalse(intent.released);
        assertFalse(intent.revoked);

        assertEq(vault.totalEscrowed(sender), AMOUNT);
        assertTrue(vault.intentExists(INTENT_ID_1));
    }

    function testCannotCreateDuplicateIntent() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.startPrank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        vm.expectRevert(EscrowVault.IntentAlreadyExists.selector);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);
        vm.stopPrank();
    }

    function testCannotCreateWithZeroAmount() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.prank(sender);
        vm.expectRevert(EscrowVault.InvalidAmount.selector);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, 0, expiry);
    }

    function testCannotCreateWithPastExpiry() public {
        uint64 pastExpiry = uint64(block.timestamp - 1);

        vm.prank(sender);
        vm.expectRevert(EscrowVault.InvalidExpiry.selector);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, pastExpiry);
    }

    function testCannotCreateWithTooLongExpiry() public {
        uint64 tooLongExpiry = uint64(block.timestamp + vault.MAX_EXPIRY_DURATION() + 1);

        vm.prank(sender);
        vm.expectRevert(EscrowVault.InvalidExpiry.selector);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, tooLongExpiry);
    }

    function testReleaseIntent() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        // Create intent
        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        // Create valid proof
        bytes memory proof = _createValidProof(INTENT_ID_1, PHONE_HASH_1, recipient);

        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        vm.expectEmit(true, true, false, true);
        emit EscrowReleased(INTENT_ID_1, recipient, AMOUNT);

        vault.release(INTENT_ID_1, recipient, proof);

        IEscrowVault.Intent memory intent = vault.getIntent(INTENT_ID_1);
        assertTrue(intent.released);
        assertEq(token.balanceOf(recipient), recipientBalanceBefore + AMOUNT);
        assertEq(vault.totalEscrowed(sender), 0);
    }

    function testCannotReleaseWithInvalidProof() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        bytes memory invalidProof = "invalid proof";

        vm.expectRevert(EscrowVault.InvalidRecipientProof.selector);
        vault.release(INTENT_ID_1, recipient, invalidProof);
    }

    function testCannotReleaseExpiredIntent() public {
        uint64 shortExpiry = uint64(block.timestamp + 1);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, shortExpiry);

        // Fast forward past expiry
        vm.warp(block.timestamp + 2);

        bytes memory proof = _createValidProof(INTENT_ID_1, PHONE_HASH_1, recipient);

        vm.expectRevert(EscrowVault.IntentExpired.selector);
        vault.release(INTENT_ID_1, recipient, proof);
    }

    function testCannotReleaseAlreadyReleasedIntent() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        bytes memory proof = _createValidProof(INTENT_ID_1, PHONE_HASH_1, recipient);
        vault.release(INTENT_ID_1, recipient, proof);

        vm.expectRevert(EscrowVault.IntentAlreadyReleased.selector);
        vault.release(INTENT_ID_1, recipient, proof);
    }

    function testRevokeIntent() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        uint256 senderBalanceBefore = token.balanceOf(sender);

        vm.expectEmit(true, false, false, false);
        emit EscrowRevoked(INTENT_ID_1);

        vm.prank(sender);
        vault.revoke(INTENT_ID_1);

        IEscrowVault.Intent memory intent = vault.getIntent(INTENT_ID_1);
        assertTrue(intent.revoked);
        assertEq(token.balanceOf(sender), senderBalanceBefore + AMOUNT);
        assertEq(vault.totalEscrowed(sender), 0);
    }

    function testCannotRevokeAfterWindow() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        // Fast forward past revoke window
        vm.warp(block.timestamp + vault.DEFAULT_REVOKE_WINDOW() + 1);

        vm.prank(sender);
        vm.expectRevert(EscrowVault.RevokeWindowExpired.selector);
        vault.revoke(INTENT_ID_1);
    }

    function testCannotRevokeUnauthorized() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        vm.prank(nonOwner);
        vm.expectRevert(EscrowVault.UnauthorizedSender.selector);
        vault.revoke(INTENT_ID_1);
    }

    function testRefundExpiredIntent() public {
        uint64 shortExpiry = uint64(block.timestamp + 1);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, shortExpiry);

        // Fast forward past expiry
        vm.warp(block.timestamp + 2);

        uint256 senderBalanceBefore = token.balanceOf(sender);

        vm.expectEmit(true, false, false, false);
        emit EscrowRefunded(INTENT_ID_1);

        // Anyone can trigger refund after expiry
        vm.prank(nonOwner);
        vault.refund(INTENT_ID_1);

        IEscrowVault.Intent memory intent = vault.getIntent(INTENT_ID_1);
        assertTrue(intent.revoked);
        assertEq(token.balanceOf(sender), senderBalanceBefore + AMOUNT);
    }

    function testCannotRefundBeforeExpiry() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        vm.expectRevert(EscrowVault.RefundNotAvailable.selector);
        vault.refund(INTENT_ID_1);
    }

    function testCanRelease() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        assertTrue(vault.canRelease(INTENT_ID_1));

        // After expiry
        vm.warp(expiry + 1);
        assertFalse(vault.canRelease(INTENT_ID_1));
    }

    function testCanRevoke() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        assertTrue(vault.canRevoke(INTENT_ID_1));

        // After revoke window
        vm.warp(block.timestamp + vault.DEFAULT_REVOKE_WINDOW() + 1);
        assertFalse(vault.canRevoke(INTENT_ID_1));
    }

    function testCanRefund() public {
        uint64 shortExpiry = uint64(block.timestamp + 1);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, shortExpiry);

        assertFalse(vault.canRefund(INTENT_ID_1));

        // After expiry
        vm.warp(shortExpiry + 1);
        assertTrue(vault.canRefund(INTENT_ID_1));
    }

    function testSetProofSigner() public {
        address newSigner = makeAddr("newSigner");

        vm.prank(owner);
        vault.setProofSigner(newSigner);

        assertEq(vault.proofSigner(), newSigner);
    }

    function testSetProofSignerOnlyOwner() public {
        address newSigner = makeAddr("newSigner");

        vm.prank(nonOwner);
        vm.expectRevert();
        vault.setProofSigner(newSigner);
    }

    function testEmergencyWithdraw() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        vm.prank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);

        uint256 emergencyAmount = AMOUNT / 2;
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        vm.prank(owner);
        vault.emergencyWithdraw(owner, emergencyAmount);

        assertEq(token.balanceOf(owner), ownerBalanceBefore + emergencyAmount);
    }

    function testEmergencyWithdrawOnlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        vault.emergencyWithdraw(nonOwner, AMOUNT);
    }

    function testGetIntentNonExistent() public {
        vm.expectRevert(EscrowVault.IntentNotFound.selector);
        vault.getIntent(INTENT_ID_1);
    }

    function testMultipleIntents() public {
        uint64 expiry = uint64(block.timestamp + EXPIRY_DURATION);

        // Create multiple intents
        vm.startPrank(sender);
        vault.create(INTENT_ID_1, sender, PHONE_HASH_1, AMOUNT, expiry);
        vault.create(INTENT_ID_2, sender, PHONE_HASH_2, AMOUNT, expiry);
        vm.stopPrank();

        assertEq(vault.totalEscrowed(sender), AMOUNT * 2);

        // Release one
        bytes memory proof1 = _createValidProof(INTENT_ID_1, PHONE_HASH_1, recipient);
        vault.release(INTENT_ID_1, recipient, proof1);

        assertEq(vault.totalEscrowed(sender), AMOUNT);

        // Revoke the other
        vm.prank(sender);
        vault.revoke(INTENT_ID_2);

        assertEq(vault.totalEscrowed(sender), 0);
    }

    function testFuzzCreateIntent(
        bytes32 intentId,
        bytes32 phoneHash,
        uint256 amount,
        uint64 timeOffset
    ) public {
        vm.assume(intentId != bytes32(0));
        vm.assume(phoneHash != bytes32(0));
        vm.assume(amount > 0 && amount <= AMOUNT * 10);
        vm.assume(timeOffset > 0 && timeOffset <= vault.MAX_EXPIRY_DURATION());

        uint64 expiry = uint64(block.timestamp + timeOffset);

        token.mint(sender, amount);

        vm.prank(sender);
        vault.create(intentId, sender, phoneHash, amount, expiry);

        IEscrowVault.Intent memory intent = vault.getIntent(intentId);
        assertEq(intent.sender, sender);
        assertEq(intent.recipHash, phoneHash);
        assertEq(intent.amount, amount);
        assertEq(intent.expiry, expiry);
    }

    function _createValidProof(bytes32 intentId, bytes32 phoneHash, address recipientAccount)
        internal
        view
        returns (bytes memory)
    {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(intentId, phoneHash, recipientAccount))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            uint256(keccak256(abi.encodePacked("proofSigner"))), // ProofSigner's private key
            messageHash
        );

        return abi.encodePacked(r, s, v);
    }
}
