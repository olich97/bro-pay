// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "eth-infinitism-account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "eth-infinitism-account-abstraction/contracts/interfaces/IPaymaster.sol";
import "eth-infinitism-account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "eth-infinitism-account-abstraction/contracts/interfaces/IStakeManager.sol";
import "eth-infinitism-account-abstraction/contracts/interfaces/ISenderCreator.sol";

import "../src/BroPaymaster.sol";

contract MockEntryPoint is IEntryPoint {
    mapping(address => uint256) public deposits;

    function balanceOf(address account) external view returns (uint256) {
        return deposits[account];
    }

    function depositTo(address account) external payable {
        deposits[account] += msg.value;
    }

    function withdrawTo(address payable withdrawAddress, uint256 amount) external {
        deposits[msg.sender] -= amount;
        withdrawAddress.transfer(amount);
    }

    // Full interface compliance
    function handleOps(PackedUserOperation[] calldata, address payable) external {}
    function handleAggregatedOps(IEntryPoint.UserOpsPerAggregator[] calldata, address payable)
        external
    {}

    function simulateValidation(PackedUserOperation calldata) external returns (uint256) {
        return 0;
    }

    function getNonce(address, uint192) external pure returns (uint256) {
        return 0;
    }

    function getUserOpHash(PackedUserOperation calldata) external pure returns (bytes32) {
        return bytes32(0);
    }

    // IStakeManager functions
    function addStake(uint32) external payable {}
    function unlockStake() external {}
    function withdrawStake(address payable) external {}

    function getDepositInfo(address account)
        external
        view
        returns (IStakeManager.DepositInfo memory info)
    {
        info.deposit = deposits[account];
        info.staked = false;
        info.stake = 0;
        info.unstakeDelaySec = 0;
        info.withdrawTime = 0;
    }

    // INonceManager functions
    function incrementNonce(uint192) external {}

    // Additional IEntryPoint functions
    function getSenderAddress(bytes memory) external {}
    function delegateAndRevert(address, bytes calldata) external {}

    function senderCreator() external view returns (ISenderCreator) {
        return ISenderCreator(address(0));
    }
}

contract BroPaymasterTest is Test {
    BroPaymaster public paymaster;
    MockEntryPoint public entryPoint;

    address public owner;
    address public attestationValidator;
    address public user1;
    address public user2;
    address public nonOwner;

    event PolicyUpdated(bytes32 indexed policyHash);
    event UserSponsored(address indexed user, uint256 actualGasCost);
    event AttestationValidated(address indexed user, bytes32 attestationHash);

    function setUp() public {
        owner = makeAddr("owner");
        attestationValidator = makeAddr("attestationValidator");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        nonOwner = makeAddr("nonOwner");

        // Deploy mock EntryPoint
        entryPoint = new MockEntryPoint();

        // Deploy BroPaymaster
        vm.startPrank(owner);
        address paymasterProxy = Upgrades.deployUUPSProxy(
            "BroPaymaster",
            abi.encodeCall(BroPaymaster.initialize, (entryPoint, owner, attestationValidator))
        );
        paymaster = BroPaymaster(payable(paymasterProxy));
        vm.stopPrank();

        // Fund paymaster
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        paymaster.addDeposit{value: 1 ether}();
    }

    function testInitialize() public {
        assertEq(address(paymaster.entryPoint()), address(entryPoint));
        assertEq(paymaster.owner(), owner);
        assertEq(paymaster.attestationValidator(), attestationValidator);
        assertEq(paymaster.maxGasPerOp(), 300_000);
        assertEq(paymaster.maxDailyGasPerUser(), 0.01 ether);
    }

    function testAddToWhitelist() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        vm.prank(owner);
        paymaster.addToWhitelist(users);

        assertTrue(paymaster.isUserWhitelisted(user1));
        assertTrue(paymaster.isUserWhitelisted(user2));
        assertFalse(paymaster.isUserWhitelisted(nonOwner));
    }

    function testAddToWhitelistOnlyOwner() public {
        address[] memory users = new address[](1);
        users[0] = user1;

        vm.prank(nonOwner);
        vm.expectRevert();
        paymaster.addToWhitelist(users);
    }

    function testRemoveFromWhitelist() public {
        address[] memory users = new address[](1);
        users[0] = user1;

        vm.prank(owner);
        paymaster.addToWhitelist(users);
        assertTrue(paymaster.isUserWhitelisted(user1));

        vm.prank(owner);
        paymaster.removeFromWhitelist(users);
        assertFalse(paymaster.isUserWhitelisted(user1));
    }

    function testSetPolicy() public {
        bytes memory policy = "test policy data";
        bytes32 expectedHash = keccak256(policy);

        vm.expectEmit(true, false, false, false);
        emit PolicyUpdated(expectedHash);

        vm.prank(owner);
        paymaster.setPolicy(policy);

        assertEq(paymaster.policyHash(), expectedHash);
    }

    function testSetPolicyOnlyOwner() public {
        bytes memory policy = "test policy data";

        vm.prank(nonOwner);
        vm.expectRevert();
        paymaster.setPolicy(policy);
    }

    function testSponsor() public {
        bytes memory userOp = "mock userOp";
        bytes memory attestation = "mock attestation";

        bool shouldSponsor = paymaster.sponsor(userOp, attestation);
        assertTrue(shouldSponsor); // Always true for PoC
    }

    function testValidatePaymasterUserOp() public {
        // Add user to whitelist
        address[] memory users = new address[](1);
        users[0] = user1;
        vm.prank(owner);
        paymaster.addToWhitelist(users);

        // Create mock UserOperation
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: user1,
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(uint256(100000) | (uint256(100000) << 128)),
            preVerificationGas: 21000,
            gasFees: bytes32(uint256(1e9) | (uint256(1e9) << 128)),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = keccak256("mockHash");
        uint256 maxCost = 100000 * 1e9; // Should be within limits

        // This should succeed for whitelisted user with reasonable gas cost
        (bytes memory context, uint256 validationData) =
            this.callValidatePaymasterUserOp(userOp, userOpHash, maxCost);

        assertEq(validationData, 0); // Success
        assertTrue(context.length > 0); // Should have context
    }

    function testValidatePaymasterUserOpGasTooHigh() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        vm.prank(owner);
        paymaster.addToWhitelist(users);

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: user1,
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(uint256(1000000) | (uint256(100000) << 128)), // High gas
            preVerificationGas: 21000,
            gasFees: bytes32(uint256(1e9) | (uint256(1e9) << 128)),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = keccak256("mockHash");
        uint256 maxCost = paymaster.maxGasPerOp() * 1e9 + 1; // Exceed limit

        (, uint256 validationData) = this.callValidatePaymasterUserOp(userOp, userOpHash, maxCost);

        assertEq(validationData, 1); // Failure
    }

    function testValidatePaymasterUserOpNotWhitelisted() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: user1, // Not whitelisted
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(uint256(100000) | (uint256(100000) << 128)),
            preVerificationGas: 21000,
            gasFees: bytes32(uint256(1e9) | (uint256(1e9) << 128)),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = keccak256("mockHash");
        uint256 maxCost = 100000 * 1e9;

        (, uint256 validationData) = this.callValidatePaymasterUserOp(userOp, userOpHash, maxCost);

        assertEq(validationData, 1); // Failure
    }

    function testGetDailyGasSpent() public {
        (uint256 spent, uint256 remaining) = paymaster.getDailyGasSpent(user1);
        assertEq(spent, 0);
        assertEq(remaining, paymaster.maxDailyGasPerUser());
    }

    function testSetMaxGasPerOp() public {
        uint256 newLimit = 500_000;

        vm.prank(owner);
        paymaster.setMaxGasPerOp(newLimit);

        assertEq(paymaster.maxGasPerOp(), newLimit);
    }

    function testSetMaxGasPerOpOnlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        paymaster.setMaxGasPerOp(500_000);
    }

    function testSetMaxDailyGasPerUser() public {
        uint256 newLimit = 0.02 ether;

        vm.prank(owner);
        paymaster.setMaxDailyGasPerUser(newLimit);

        assertEq(paymaster.maxDailyGasPerUser(), newLimit);
    }

    function testSetMinDepositRequired() public {
        uint256 newMin = 0.2 ether;

        vm.prank(owner);
        paymaster.setMinDepositRequired(newMin);

        assertEq(paymaster.minDepositRequired(), newMin);
    }

    function testSetAttestationValidator() public {
        address newValidator = makeAddr("newValidator");

        vm.prank(owner);
        paymaster.setAttestationValidator(newValidator);

        assertEq(paymaster.attestationValidator(), newValidator);
    }

    function testGetDeposit() public {
        uint256 deposit = paymaster.getDeposit();
        assertEq(deposit, 1 ether); // From setUp
    }

    function testAddDeposit() public {
        uint256 additionalAmount = 0.5 ether;
        vm.deal(owner, additionalAmount);

        uint256 depositBefore = paymaster.getDeposit();

        vm.prank(owner);
        paymaster.addDeposit{value: additionalAmount}();

        assertEq(paymaster.getDeposit(), depositBefore + additionalAmount);
    }

    function testAddDepositOnlyOwner() public {
        vm.deal(nonOwner, 1 ether);

        vm.prank(nonOwner);
        vm.expectRevert();
        paymaster.addDeposit{value: 1 ether}();
    }

    function testWithdrawDeposit() public {
        address payable withdrawAddr = payable(makeAddr("withdrawAddr"));
        uint256 withdrawAmount = 0.1 ether;

        uint256 depositBefore = paymaster.getDeposit();
        uint256 withdrawAddrBalanceBefore = withdrawAddr.balance;

        vm.prank(owner);
        paymaster.withdrawDeposit(withdrawAddr, withdrawAmount);

        assertEq(paymaster.getDeposit(), depositBefore - withdrawAmount);
        assertEq(withdrawAddr.balance, withdrawAddrBalanceBefore + withdrawAmount);
    }

    function testWithdrawDepositOnlyOwner() public {
        address payable withdrawAddr = payable(makeAddr("withdrawAddr"));

        vm.prank(nonOwner);
        vm.expectRevert();
        paymaster.withdrawDeposit(withdrawAddr, 0.1 ether);
    }

    function testReceiveEther() public {
        uint256 amount = 0.5 ether;
        vm.deal(address(this), amount);

        uint256 depositBefore = paymaster.getDeposit();

        (bool success,) = payable(address(paymaster)).call{value: amount}("");
        assertTrue(success);

        assertEq(paymaster.getDeposit(), depositBefore + amount);
    }

    function testDailyLimitTracking() public {
        // This test would need to mock the _postOp functionality
        // Since _postOp is internal, we'll test the daily gas tracking indirectly

        uint256 today = block.timestamp / 1 days;

        // Simulate gas spending by directly accessing storage (for testing)
        // In practice, this would happen through _postOp
        (uint256 spent, uint256 remaining) = paymaster.getDailyGasSpent(user1);
        assertEq(spent, 0);
        assertEq(remaining, paymaster.maxDailyGasPerUser());
    }

    function testInsufficientDeposit() public {
        // Withdraw most of the deposit
        vm.prank(owner);
        paymaster.withdrawDeposit(payable(owner), 0.95 ether);

        address[] memory users = new address[](1);
        users[0] = user1;
        vm.prank(owner);
        paymaster.addToWhitelist(users);

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: user1,
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(uint256(100000) | (uint256(100000) << 128)),
            preVerificationGas: 21000,
            gasFees: bytes32(uint256(1e9) | (uint256(1e9) << 128)),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = keccak256("mockHash");
        uint256 maxCost = 100000 * 1e9;

        (, uint256 validationData) = this.callValidatePaymasterUserOp(userOp, userOpHash, maxCost);

        assertEq(validationData, 1); // Should fail due to insufficient deposit
    }

    function testFuzzMaxGasSettings(uint256 maxGas, uint256 maxDaily) public {
        vm.assume(maxGas > 0 && maxGas < 10_000_000);
        vm.assume(maxDaily > 0 && maxDaily < 100 ether);

        vm.startPrank(owner);
        paymaster.setMaxGasPerOp(maxGas);
        paymaster.setMaxDailyGasPerUser(maxDaily);
        vm.stopPrank();

        assertEq(paymaster.maxGasPerOp(), maxGas);
        assertEq(paymaster.maxDailyGasPerUser(), maxDaily);
    }

    // Helper function to test internal _validatePaymasterUserOp
    function callValidatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external view returns (bytes memory context, uint256 validationData) {
        return paymaster.testValidatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    receive() external payable {}
}
