# Bro Pay v1 Smart Contracts

**WhatsApp-Native Payment System using ERC-4337 Account Abstraction**

Bro Pay v1 is a revolutionary payment system that enables WhatsApp users to send and receive payments through signed Payment Capsules without requiring a native mobile app. Built on ERC-4337 Account Abstraction with passkey authentication and deployed on Base L2.

## 🏗️ Architecture Overview

### Core Contracts

- **`AccountFactory.sol`** - ERC-4337 compatible factory for deterministic smart account deployment using CREATE2 with phone hash salts
- **`SmartAccount.sol`** - ERC-4337 BaseAccount implementation with WebAuthn passkey authentication and owner rotation
- **`EscrowVault.sol`** - Payment Intent escrow system with recipient phone hash binding and time-based revoke/refund
- **`BroPaymaster.sol`** - Enhanced ERC-4337 paymaster with policy engine, whitelisting, and gas sponsorship limits
- **`TimelockedUUPS.sol`** - Base contract for upgradeable contracts with time-delayed upgrade mechanism

### Key Features

- 🔐 **Passkey Authentication** - WebAuthn P-256 signatures, no seed phrases required
- 📱 **Phone Hash Privacy** - Phone numbers hashed for privacy, deterministic account addressing
- 💸 **Payment Capsules** - Signed JWS links shareable via WhatsApp for payments
- ⛽ **Gas Sponsorship** - Paymaster covers transaction costs with policy-based limits
- 🔄 **Account Recovery** - Owner rotation for lost device scenarios
- 🏪 **Intent-Based Payments** - Escrow system with recipient verification before release
- 🌐 **Multi-Chain Ready** - Dynamic deployment support for Base Sepolia, Mainnet, and local chains

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) - Ethereum development toolkit
- [Node.js](https://nodejs.org/) - For package scripts
- Base Sepolia ETH for deployment

### Installation

```bash
# Clone and setup
git clone <repo-url>
cd bro-pay/contracts

# Install dependencies
forge install
npm install

# Build contracts
npm run build
```

### Environment Setup

Create `.env` file:

```bash
# Required for deployment
PRIVATE_KEY=0x... # Deployer private key
RPC_URL_BASE_SEPOLIA=https://sepolia.base.org
RPC_URL_BASE_MAINNET=https://mainnet.base.org

# Optional for local testing
MOCK_USDC=0x... # Local USDC address
MOCK_ENTRYPOINT=0x... # Local EntryPoint address
```

## 📜 Available Scripts

### Development

```bash
# Build all contracts
npm run build

# Run all tests
npm run test

# Run tests with gas reporting
npm run test:gas

# Check test coverage
npm run coverage

# Format code
npm run format

# Create gas snapshots
npm run snapshot
```

### Deployment

```bash
# Deploy to Base Sepolia
npm run deploy:base-sepolia

# Deploy to Base Mainnet (production)
npm run deploy:base-mainnet

# Deploy to local Anvil
npm run deploy:local

# Verify contracts on Basescan
npm run verify:base-sepolia
npm run verify:base-mainnet
```

### Development Tools

```bash
# Start local blockchain
npm run anvil

# Interactive Solidity REPL
npm run chisel

# Clean build artifacts
npm run clean
```

## 🔧 Configuration

### Chain Configuration

The deployment script automatically detects chain configuration:

| Chain | Chain ID | EntryPoint | USDC |
|-------|----------|------------|------|
| Base Sepolia | 84532 | 0x0576a174D229E3cFA37253523E645A78A0C91B57 | 0x036CbD53842c5426634e7929541eC2318f3dCF7e |
| Base Mainnet | 8453 | 0x0576a174D229E3cFA37253523E645A78A0C91B57 | 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 |
| Local Anvil | 31337 | Configurable via env vars | Configurable via env vars |

### Contract Parameters

**BroPaymaster Limits:**
- Max gas per operation: 300,000 gas
- Max daily gas per user: 0.01 ETH
- Minimum deposit required: 0.1 ETH

**EscrowVault Settings:**
- Payment intent expiry: Configurable per payment
- Revoke period: Before recipient claims
- Proof validation: ECDSA signature verification

## 🧪 Testing

### Test Suites

- **`AccountFactory.t.sol`** - Factory deployment, salt generation, deterministic addressing (13 tests)
- **`SmartAccount.t.sol`** - ERC-4337 account functionality, passkey validation, owner rotation (15 tests)
- **`EscrowVault.t.sol`** - Payment intents, escrow mechanics, recipient verification (20 tests)
- **`BroPaymaster.t.sol`** - Gas sponsorship, policy validation, user management (18 tests)

### Running Specific Tests

```bash
# Run specific test file
forge test --match-contract AccountFactoryTest

# Run specific test function
forge test --match-test testDeploy

# Run tests with verbose output
forge test -vvv

# Run fuzz tests with custom runs
forge test --fuzz-runs 1000
```

## 🚢 Deployment

### Step-by-Step Deployment

1. **Prepare Environment**
   ```bash
   cp .env.example .env
   # Add your PRIVATE_KEY and RPC URLs
   ```

2. **Fund Deployer Account**
   - Get Base Sepolia ETH from [faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet)
   - Ensure at least 0.1 ETH for deployment and paymaster funding

3. **Deploy Contracts**
   ```bash
   npm run deploy:base-sepolia
   ```

4. **Verify Deployment**
   - Check deployed addresses in console output
   - Verify contracts on [Basescan](https://sepolia.basescan.org/)

### Expected Gas Costs

| Contract | Deployment Cost | Size |
|----------|----------------|------|
| SmartAccount (Implementation) | ~1.2M gas | 5.5KB |
| AccountFactory (Proxy) | ~800K gas | 3.2KB |
| EscrowVault (Proxy) | ~900K gas | 3.8KB |
| BroPaymaster (Proxy) | ~1.1M gas | 4.1KB |

## 🔍 Contract Interactions

### Creating Smart Accounts

```solidity
// Generate deterministic salt from phone hash
bytes32 salt = accountFactory.generateSalt(phoneHash);

// Deploy account with passkey data
bytes memory initData = abi.encode(ownerAddress, credentialId, publicKeyHash);
address account = accountFactory.deploy(salt, initData);
```

### Creating Payment Intents

```solidity
// Create payment intent with recipient phone hash
bytes32 intentId = keccak256(abi.encode(sender, recipientPhoneHash, amount, nonce));
escrowVault.create(intentId, sender, recipientPhoneHash, amount, expiry);
```

### Gas Sponsorship

```solidity
// Add users to paymaster whitelist
address[] memory users = [userAddress];
broPaymaster.addToWhitelist(users);

// Check daily gas limits
(uint256 spent, uint256 remaining) = broPaymaster.getDailyGasSpent(userAddress);
```

## 🛡️ Security

### Audit Status
- ⚠️ **Not audited** - This is a v1 implementation for demonstration purposes
- 🔍 **Internal review** completed
- 📋 **Test coverage** >90% for core functionality

### Security Features

- **Access Control** - OpenZeppelin's Ownable for administrative functions
- **Reentrancy Protection** - ReentrancyGuard on critical functions
- **Upgrade Safety** - Time-locked UUPS upgrades
- **Input Validation** - Comprehensive parameter checking
- **Gas Limits** - Protection against gas griefing attacks

### Best Practices

- Always verify contract addresses before interaction
- Use hardware wallets for deployment and administrative functions  
- Monitor paymaster deposits and refill as needed
- Regularly review whitelist and spending limits

## 📚 Integration Guide

### Frontend Integration

1. **Account Discovery**
   ```javascript
   const phoneHash = keccak256(phoneNumber);
   const salt = await accountFactory.generateSalt(phoneHash);
   const accountAddress = await accountFactory.computeAddress(salt);
   ```

2. **Payment Capsule Creation**
   ```javascript
   const intentId = generateIntentId(sender, recipientPhoneHash, amount);
   const capsule = createPaymentCapsule(intentId, amount, expiry);
   const whatsappLink = `https://wa.me/?text=${encodeURIComponent(capsule)}`;
   ```

3. **WebAuthn Signing**
   ```javascript
   const userOpHash = await entryPoint.getUserOpHash(userOp);
   const signature = await signWithPasskey(userOpHash, credentialId);
   ```

### API Integration

The contracts expose standard ERC-4337 interfaces compatible with:
- [Pimlico](https://pimlico.io/) - Account Abstraction infrastructure
- [Stackup](https://stackup.sh/) - Bundler services
- [Alchemy](https://www.alchemy.com/account-abstraction) - AA developer tools

## 🤝 Contributing

### Development Workflow

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Run tests: `npm run test`
4. Check formatting: `npm run format`
5. Commit changes: `git commit -m 'Add amazing feature'`
6. Push branch: `git push origin feature/amazing-feature`
7. Open Pull Request

### Code Standards

- Follow [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Add comprehensive tests for new features
- Include NatSpec documentation
- Ensure gas efficiency

## 📞 Support

- 📧 **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/your-repo/discussions)
- 📖 **Docs**: [Technical Specification](../bro_pay_v_1_detailed_technical_specification_capsules_no_app_whats_app_ux.md)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

**⚠️ Disclaimer**: This is experimental software for demonstration purposes. Use at your own risk. Always conduct thorough testing before production deployment.