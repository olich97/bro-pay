// SPDX‑License‑Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {AccountFactory} from "../src/AccountFactory.sol";
import {SmartAccount} from "../src/SmartAccount.sol";
import {EscrowVault} from "../src/EscrowVault.sol";
import {BroPaymaster} from "../src/BroPaymaster.sol";
import "eth-infinitism-account-abstraction/contracts/interfaces/IEntryPoint.sol";

/**
 * @title Bro Pay v1 Deployment Script
 * @notice Deploy ERC-4337 compatible contracts for any target chain
 * @dev Handles Base Sepolia, Base Mainnet, and local chains dynamically
 */
contract Deploy is Script {
    struct ChainConfig {
        address entryPoint;
        address usdc;
        string name;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        ChainConfig memory config = getChainConfig();

        console2.log("Deploying Bro Pay v1 contracts...");
        console2.log("Deployer:", deployer);
        console2.log("Network:", config.name);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // First deploy SmartAccount implementation
        SmartAccount accountImpl = new SmartAccount(IEntryPoint(config.entryPoint));

        // Deploy AccountFactory
        AccountFactory factory = AccountFactory(
            Upgrades.deployUUPSProxy(
                "AccountFactory",
                abi.encodeCall(AccountFactory.initialize, (deployer, address(accountImpl)))
            )
        );

        // Deploy EscrowVault
        EscrowVault escrow = EscrowVault(
            Upgrades.deployUUPSProxy(
                "EscrowVault",
                abi.encodeCall(
                    EscrowVault.initialize,
                    (config.usdc, deployer, deployer) // token, proofSigner, owner
                )
            )
        );

        // Deploy BroPaymaster
        address paymasterProxy = Upgrades.deployUUPSProxy(
            "BroPaymaster",
            abi.encodeCall(
                BroPaymaster.initialize,
                (IEntryPoint(config.entryPoint), deployer, deployer) // entryPoint, owner, attestationValidator
            )
        );
        BroPaymaster paymaster = BroPaymaster(payable(paymasterProxy));

        // Fund paymaster with ETH for gas sponsorship
        uint256 fundAmount = (block.chainid == 31337) ? 1 ether : 0.01 ether; // More for local
        paymaster.addDeposit{value: fundAmount}();

        // Whitelist deployer for testing
        address[] memory users = new address[](1);
        users[0] = deployer;
        paymaster.addToWhitelist(users);

        console2.log("");
        console2.log("=== Bro Pay v1 Deployment Complete ===");
        console2.log("AccountFactory:", address(factory));
        console2.log("EscrowVault:", address(escrow));
        console2.log("BroPaymaster:", address(paymaster));
        console2.log("");
        console2.log("=== Configuration ===");
        console2.log("EntryPoint:", config.entryPoint);
        console2.log("USDC Token:", config.usdc);
        console2.log("Paymaster Deposit:", paymaster.getDeposit());
        console2.log("Deployer Whitelisted:", paymaster.isUserWhitelisted(deployer));

        vm.stopBroadcast();
    }

    function getChainConfig() internal view returns (ChainConfig memory config) {
        uint256 chainId = block.chainid;

        if (chainId == 84532) {
            // Base Sepolia
            config = ChainConfig({
                entryPoint: 0x0576a174D229E3cFA37253523E645A78A0C91B57,
                usdc: 0x036CbD53842c5426634e7929541eC2318f3dCF7e,
                name: "Base Sepolia"
            });
        } else if (chainId == 8453) {
            // Base Mainnet
            config = ChainConfig({
                entryPoint: 0x0576a174D229E3cFA37253523E645A78A0C91B57,
                usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
                name: "Base Mainnet"
            });
        } else if (chainId == 31337) {
            // Local Anvil/Hardhat
            address mockUsdc = vm.envOr("MOCK_USDC", address(0));
            address mockEntryPoint = vm.envOr("MOCK_ENTRYPOINT", address(0));

            config = ChainConfig({
                entryPoint: mockEntryPoint != address(0)
                    ? mockEntryPoint
                    : 0x0576a174D229E3cFA37253523E645A78A0C91B57,
                usdc: mockUsdc != address(0) ? mockUsdc : address(0),
                name: "Local"
            });
        } else {
            // Fallback - use env vars
            config = ChainConfig({
                entryPoint: vm.envAddress("ENTRYPOINT_ADDRESS"),
                usdc: vm.envAddress("USDC_ADDRESS"),
                name: "Custom"
            });
        }

        require(config.entryPoint != address(0), "EntryPoint address not configured");
        require(config.usdc != address(0), "USDC address not configured");
    }
}
