# Development Guide

This guide covers development workflows, testing strategies, and deployment procedures for Bro Pay v1 smart contracts.

## 🛠️ Development Setup

### Prerequisites
- **Foundry** >= 0.2.0
- **Node.js** >= 16.0.0 
- **Git** for version control

### Initial Setup
```bash
# Clone repository
git clone <your-repo-url>
cd bro-pay/contracts

# Install Foundry dependencies
forge install

# Install Node dependencies (if any)
npm install

# Copy environment template
cp .env.example .env
# Edit .env with your values

# Build contracts
npm run build
```

## 🧪 Testing Strategy

### Test Structure
```
test/
├── AccountFactory.t.sol     # Factory deployment & addressing
├── SmartAccount.t.sol       # ERC-4337 account functionality  
├── EscrowVault.t.sol        # Payment intent escrow
└── BroPaymaster.t.sol       # Gas sponsorship & policies
```

### Running Tests

#### Basic Testing
```bash
# Run all tests
npm run test

# Run with gas reporting
npm run test:gas

# Run specific contract tests
npm run gas:paymaster
npm run gas:smartaccount

# Verbose output for debugging
npm run test:verbose
```

#### Advanced Testing
```bash
# Fuzz testing with 1000 runs
npm run test:fuzz

# Coverage analysis
npm run test:coverage

# Debug specific test
forge test --debug testFunctionName
```

### Test Categories

#### Unit Tests
- Individual function testing
- Edge case validation
- Access control verification
- Gas optimization checks

#### Integration Tests
- Cross-contract interactions
- ERC-4337 compliance
- Policy engine validation
- Upgrade mechanisms

#### Fuzz Tests
- Property-based testing
- Random input validation
- Boundary condition testing
- Invariant verification

## 📦 Contract Architecture

### Core Components

#### 1. AccountFactory
**Purpose**: Deterministic smart account deployment
```solidity
// Key functions
function generateSalt(bytes32 phoneHash) -> bytes32
function computeAddress(bytes32 salt) -> address  
function deploy(bytes32 salt, bytes calldata initData) -> address
```

#### 2. SmartAccount
**Purpose**: ERC-4337 compatible account with passkey auth
```solidity
// Key functions
function initialize(bytes calldata initData)
function execute(address dest, uint256 value, bytes calldata data)
function rotateOwner(address newOwner, bytes32 credId, bytes32 pubKeyHash)
```

#### 3. EscrowVault 
**Purpose**: Payment intent escrow with recipient verification
```solidity
// Key functions
function create(bytes32 intentId, address sender, bytes32 recipHash, ...)
function release(bytes32 intentId, bytes calldata proof)
function revoke(bytes32 intentId)
```

#### 4. BroPaymaster
**Purpose**: Gas sponsorship with policy validation
```solidity
// Key functions
function validatePaymasterUserOp(...) -> (bytes memory, uint256)
function addToWhitelist(address[] calldata users)
function getDailyGasSpent(address user) -> (uint256, uint256)
```

## 🚀 Deployment Process

### Local Development
```bash
# Start local blockchain
npm run anvil

# Deploy to local (in another terminal)
npm run deploy:local
```

### Testnet Deployment
```bash
# Prepare environment
export PRIVATE_KEY="0x..."
export RPC_URL_BASE_SEPOLIA="https://sepolia.base.org" 
export BASESCAN_API_KEY="your_api_key"

# Deploy to Base Sepolia
npm run deploy:base-sepolia

# Verify contracts (automatic with deploy script)
npm run verify:base-sepolia
```

### Production Deployment
```bash
# Deploy to Base Mainnet (requires careful review)
npm run deploy:base-mainnet
```

## 🔍 Code Quality

### Static Analysis
```bash
# Format code
npm run format

# Check formatting
npm run format:check

# Run Slither (if available)
npm run slither

# Run Mythril (if available) 
npm run mythril
```

### Pre-commit Workflow
```bash
# Comprehensive check before commit
npm run precommit
```

This runs:
1. Code formatting
2. Full test suite
3. Build verification

## 📊 Gas Optimization

### Monitoring Gas Usage
```bash
# Generate gas snapshots
npm run snapshot

# Compare gas changes
forge snapshot --diff

# Gas reports per contract
npm run gas:accountfactory
npm run gas:smartaccount
npm run gas:escrowvault
npm run gas:paymaster
```

### Optimization Strategies

#### Storage Layout
- Pack structs efficiently
- Use appropriate data types
- Minimize storage reads/writes

#### Function Optimization
- Use `calldata` instead of `memory` for external functions
- Cache storage variables in memory
- Batch operations when possible

#### Example Optimizations
```solidity
// ❌ Inefficient
function processUsers(address[] memory users) external {
    for (uint i = 0; i < users.length; i++) {
        whitelistedUsers[users[i]] = true;
    }
}

// ✅ Optimized  
function processUsers(address[] calldata users) external {
    uint256 length = users.length; // Cache length
    for (uint256 i; i < length;) {
        whitelistedUsers[users[i]] = true;
        unchecked { ++i; }
    }
}
```

## 🔐 Security Practices

### Development Security
- Use latest OpenZeppelin contracts
- Follow CEI (Checks-Effects-Interactions) pattern
- Implement proper access controls
- Add reentrancy protection where needed

### Testing Security
```bash
# Run security-focused tests
forge test --match-test testSecurity

# Test access controls
forge test --match-test testOnlyOwner

# Test edge cases
forge test --match-test testEdge
```

### Common Vulnerabilities to Check
- Integer overflow/underflow
- Reentrancy attacks
- Access control bypasses
- Front-running vulnerabilities
- Gas limit issues

## 📈 Performance Monitoring

### Deployment Costs
| Contract | Est. Gas | Est. Cost (20 gwei) |
|----------|----------|---------------------|
| SmartAccount Impl | 1.2M | 0.024 ETH |
| AccountFactory | 800K | 0.016 ETH |
| EscrowVault | 900K | 0.018 ETH |
| BroPaymaster | 1.1M | 0.022 ETH |

### Function Gas Costs
```bash
# Get detailed gas report
forge test --gas-report --match-contract YourContract
```

## 🐛 Debugging

### Common Issues

#### Compilation Errors
```bash
# Clean and rebuild
npm run clean && npm run build

# Check Solidity version compatibility
forge --version
```

#### Test Failures
```bash
# Run specific test with traces
forge test --match-test testName -vvvv

# Debug test execution
forge test --debug testName
```

#### Deployment Issues
```bash
# Simulate deployment without broadcasting
npm run simulation:base-sepolia

# Check deployer balance
cast balance $DEPLOYER_ADDRESS --rpc-url $RPC_URL
```

### Useful Debug Commands
```bash
# Check contract code
cast code $CONTRACT_ADDRESS --rpc-url $RPC_URL

# Call contract function
cast call $CONTRACT_ADDRESS "function()" --rpc-url $RPC_URL

# Check storage slot
cast storage $CONTRACT_ADDRESS 0 --rpc-url $RPC_URL
```

## 📚 Resources

### Documentation
- [Foundry Book](https://book.getfoundry.sh/)
- [ERC-4337 Spec](https://eips.ethereum.org/EIPS/eip-4337)
- [OpenZeppelin Docs](https://docs.openzeppelin.com/)
- [Base Documentation](https://docs.base.org/)

### Tools
- [Foundry](https://github.com/foundry-rs/foundry)
- [OpenZeppelin Wizard](https://wizard.openzeppelin.com/)
- [Base Faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet)
- [Basescan](https://basescan.org/)

### Best Practices
- [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- [Smart Contract Security](https://consensys.github.io/smart-contract-best-practices/)
- [Gas Optimization](https://gist.github.com/hrkrshnn/ee8fabd532058307229d65dcd5836ddc)

## 🤝 Contributing

### Development Workflow
1. Create feature branch
2. Write tests first (TDD)
3. Implement functionality
4. Run `npm run precommit`
5. Create pull request
6. Code review process
7. Deploy to testnet for integration testing

### Code Review Checklist
- [ ] Tests pass and have good coverage
- [ ] Code follows style guidelines
- [ ] Security considerations addressed  
- [ ] Gas usage optimized
- [ ] Documentation updated
- [ ] No breaking changes without migration plan