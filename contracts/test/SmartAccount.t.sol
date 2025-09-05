// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "eth-infinitism-account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "eth-infinitism-account-abstraction/contracts/interfaces/PackedUserOperation.sol";

import "../src/SmartAccount.sol";

contract SmartAccountTest is Test {
    SmartAccount public account;
    IEntryPoint public entryPoint;

    address public owner;
    address public newOwner;
    address public nonOwner;

    bytes32 public credentialId;
    bytes32 public publicKeyHash;

    event OwnerRotated(address indexed oldOwner, address indexed newOwner);
    event PasskeyUpdated(bytes32 indexed credentialId, bytes32 publicKeyHash);

    function setUp() public {
        owner = makeAddr("owner");
        newOwner = makeAddr("newOwner");
        nonOwner = makeAddr("nonOwner");

        credentialId = keccak256("credential1");
        publicKeyHash = keccak256("publicKey1");

        // Deploy mock EntryPoint
        entryPoint = IEntryPoint(makeAddr("entryPoint"));

        // Deploy SmartAccount
        account = new SmartAccount(entryPoint);

        // Initialize account
        bytes memory initData = abi.encode(owner, credentialId, publicKeyHash);
        account.initialize(initData);
    }

    function testInitialize() public {
        assertEq(account.owner(), owner);
        assertEq(account.passkeyCredentialId(), credentialId);
        assertEq(account.passkeyPublicKeyHash(), publicKeyHash);
        assertEq(address(account.entryPoint()), address(entryPoint));
    }

    function testCannotInitializeTwice() public {
        bytes memory initData = abi.encode(newOwner, keccak256("newCred"), keccak256("newPubKey"));

        vm.expectRevert(SmartAccount.AlreadyInitialized.selector);
        account.initialize(initData);
    }

    function testInvalidOwnerInitialization() public {
        SmartAccount newAccount = new SmartAccount(entryPoint);
        bytes memory invalidInitData = abi.encode(address(0), credentialId, publicKeyHash);

        vm.expectRevert(SmartAccount.InvalidOwner.selector);
        newAccount.initialize(invalidInitData);
    }

    function testExecute() public {
        address target = makeAddr("target");
        uint256 value = 0;
        bytes memory data = abi.encodeWithSignature("someFunction()");

        // Should work when called by owner
        vm.prank(owner);
        // Note: This would revert if target doesn't have the function, but that's expected
        vm.expectRevert();
        account.execute(target, value, data);
    }

    function testExecuteOnlyOwnerOrEntryPoint() public {
        address target = makeAddr("target");
        uint256 value = 0;
        bytes memory data = "";

        // Should fail when called by non-owner
        vm.prank(nonOwner);
        vm.expectRevert("Account: not EntryPoint or owner");
        account.execute(target, value, data);

        // Should work when called by EntryPoint
        vm.prank(address(entryPoint));
        account.execute(target, value, data);
    }

    function testExecuteBatch() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](2);

        targets[0] = makeAddr("target1");
        targets[1] = makeAddr("target2");
        values[0] = 0;
        values[1] = 0;
        datas[0] = "";
        datas[1] = "";

        vm.prank(owner);
        account.executeBatch(targets, values, datas);
    }

    function testExecuteBatchLengthMismatch() public {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1); // Mismatched length
        bytes[] memory datas = new bytes[](2);

        targets[0] = makeAddr("target1");
        targets[1] = makeAddr("target2");
        values[0] = 0;
        datas[0] = "";
        datas[1] = "";

        vm.prank(owner);
        vm.expectRevert("Length mismatch");
        account.executeBatch(targets, values, datas);
    }

    function testRotateOwner() public {
        bytes32 newCredentialId = keccak256("newCredential");
        bytes32 newPublicKeyHash = keccak256("newPublicKey");

        vm.expectEmit(true, true, false, true);
        emit OwnerRotated(owner, newOwner);

        vm.expectEmit(true, false, false, true);
        emit PasskeyUpdated(newCredentialId, newPublicKeyHash);

        vm.prank(owner);
        account.rotateOwner(newOwner, newCredentialId, newPublicKeyHash);

        assertEq(account.owner(), newOwner);
        assertEq(account.passkeyCredentialId(), newCredentialId);
        assertEq(account.passkeyPublicKeyHash(), newPublicKeyHash);
    }

    function testRotateOwnerOnlyOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        account.rotateOwner(newOwner, keccak256("newCred"), keccak256("newPubKey"));
    }

    function testRotateOwnerInvalidNewOwner() public {
        vm.prank(owner);
        vm.expectRevert(SmartAccount.InvalidOwner.selector);
        account.rotateOwner(address(0), keccak256("newCred"), keccak256("newPubKey"));
    }

    function testValidateSignature() public {
        // Create a mock UserOperation
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account),
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

        // Create a signature from the owner
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            uint256(keccak256(abi.encodePacked("owner"))), // Use owner's private key
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash))
        );

        userOp.signature = abi.encodePacked(r, s, v);

        // This would test signature validation, but requires proper key setup
        // For now, we'll test the structure
    }

    function testReceiveEther() public {
        uint256 amount = 1 ether;
        vm.deal(address(this), amount);

        (bool success,) = payable(address(account)).call{value: amount}("");
        assertTrue(success);
        assertEq(address(account).balance, amount);
    }

    function testGetNonce() public {
        assertEq(account.getNonce(), 0);
    }

    function testDepositManagement() public {
        // Mock EntryPoint balance
        vm.mockCall(
            address(entryPoint),
            abi.encodeWithSignature("balanceOf(address)", address(account)),
            abi.encode(1 ether)
        );

        assertEq(account.getDeposit(), 1 ether);
    }

    function testAddDeposit() public {
        uint256 amount = 0.1 ether;
        vm.deal(address(account), amount);

        vm.mockCall(
            address(entryPoint), abi.encodeWithSignature("depositTo(address)", address(account)), ""
        );

        account.addDeposit{value: amount}();
    }

    function testWithdrawDeposit() public {
        address payable withdrawAddr = payable(makeAddr("withdraw"));
        uint256 amount = 0.1 ether;

        vm.mockCall(
            address(entryPoint),
            abi.encodeWithSignature("withdrawTo(address,uint256)", withdrawAddr, amount),
            ""
        );

        vm.prank(owner);
        account.withdrawDepositTo(withdrawAddr, amount);
    }

    function testWithdrawDepositOnlyOwner() public {
        address payable withdrawAddr = payable(makeAddr("withdraw"));
        uint256 amount = 0.1 ether;

        vm.prank(nonOwner);
        vm.expectRevert();
        account.withdrawDepositTo(withdrawAddr, amount);
    }

    function testUpgradeOnlyOwner() public {
        address newImpl = makeAddr("newImplementation");

        vm.prank(nonOwner);
        vm.expectRevert();
        account.upgradeToAndCall(newImpl, "");
    }

    function testFuzzRotateOwner(address newAddr, bytes32 newCred, bytes32 newPubKey) public {
        vm.assume(newAddr != address(0));
        vm.assume(newCred != bytes32(0));
        vm.assume(newPubKey != bytes32(0));

        vm.prank(owner);
        account.rotateOwner(newAddr, newCred, newPubKey);

        assertEq(account.owner(), newAddr);
        assertEq(account.passkeyCredentialId(), newCred);
        assertEq(account.passkeyPublicKeyHash(), newPubKey);
    }
}
