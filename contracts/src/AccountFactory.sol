// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin-contracts/utils/Create2.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "./TimelockedUUPS.sol";

interface ISmartAccount {
    function initialize(bytes calldata initData) external;
}

interface IAccountFactory {
    function computeAddress(bytes32 salt) external view returns (address);
    function deploy(bytes32 salt, bytes calldata initData) external returns (address);
}

/**
 * @title AccountFactory
 * @notice Factory for deterministic deployment of ERC-4337 smart accounts
 * @dev Uses CREATE2 for predictable addresses based on phone hash salt
 */
contract AccountFactory is IAccountFactory, Initializable, TimelockedUUPS {
    error AccountAlreadyExists();
    error InvalidInitData();
    error ImplementationNotSet();

    event AccountDeployed(address indexed account, address indexed owner, bytes32 indexed salt);

    /// @notice SmartAccount implementation address
    address public accountImplementation;

    /**
     * @custom:oz-upgrades-unsafe-allow constructor *
     */
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, address accountImplementation_) public initializer {
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        accountImplementation = accountImplementation_;
    }

    /**
     * @notice Compute the address of a smart account before deployment
     * @param salt Deterministic salt (derived from phone hash)
     * @return account Predicted address of the smart account
     */
    function computeAddress(bytes32 salt) public view override returns (address account) {
        if (accountImplementation == address(0)) revert ImplementationNotSet();

        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(SmartAccountProxy).creationCode, abi.encode(accountImplementation)
            )
        );

        account = Create2.computeAddress(salt, bytecodeHash);
    }

    /**
     * @notice Deploy a new smart account with deterministic address
     * @param salt Deterministic salt (phoneHash derived)
     * @param initData Initialization data containing owner public key
     * @return account Address of the deployed smart account
     */
    function deploy(bytes32 salt, bytes calldata initData)
        external
        override
        returns (address account)
    {
        if (accountImplementation == address(0)) revert ImplementationNotSet();

        // Check if account already exists at computed address
        account = computeAddress(salt);
        if (account.code.length > 0) {
            revert AccountAlreadyExists();
        }

        // Validate init data contains owner address
        if (initData.length < 32) {
            revert InvalidInitData();
        }

        // Deploy proxy using CREATE2
        SmartAccountProxy proxy = new SmartAccountProxy{salt: salt}(accountImplementation);
        account = address(proxy);

        // Initialize the account with owner
        ISmartAccount(account).initialize(initData);

        // Extract owner from init data for event
        address owner = abi.decode(initData, (address));

        emit AccountDeployed(account, owner, salt);

        return account;
    }

    /**
     * @notice Update implementation address (owner only)
     * @param newImplementation New SmartAccount implementation
     */
    function setAccountImplementation(address newImplementation) external onlyOwner {
        accountImplementation = newImplementation;
    }

    /**
     * @notice Utility to generate salt from phone hash
     * @param phoneHash HMAC hash of phone number
     * @return salt Deterministic salt for CREATE2
     */
    function generateSalt(bytes32 phoneHash) external pure returns (bytes32 salt) {
        return keccak256(abi.encodePacked("BroPay.Account.v1", phoneHash));
    }
}

/**
 * @title SmartAccountProxy
 * @notice Minimal proxy for SmartAccount implementation
 */
contract SmartAccountProxy {
    address private immutable _implementation;

    constructor(address implementation_) {
        _implementation = implementation_;
    }

    function implementation() external view returns (address) {
        return _implementation;
    }

    fallback() external payable {
        address impl = _implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
