# Bro Pay v1 - Proof of Concept Development Plan

## Overview
Migration from basic payment system to WhatsApp-native Payment Capsules with ERC-4337 Account Abstraction on Base testnet.

## PoC Scope & Goals
- ✅ Validate core Payment Intent escrow mechanics
- ✅ Test ERC-4337 Account Abstraction integration
- ✅ Demonstrate WebAuthn passkey authentication
- ✅ Prove signed Payment Capsule concept
- ✅ Test Base L2 deployment and gas sponsorship

## Current Architecture vs PoC Target

### Existing Contracts (to be replaced/enhanced)
```
contracts/src/
├── BroPayAddressRegistry.sol    → REPLACE with AccountFactory
├── BroPayEscrowMinter.sol       → REPLACE with EscrowVault  
├── BroPayPaymaster.sol          → ENHANCE for ERC-4337
├── BroPayRefundGuard.sol        → INTEGRATE into EscrowVault
└── TimelockedUUPS.sol           → KEEP as base
```

### PoC Target Architecture
```
contracts/src/
├── AccountFactory.sol           → ERC-4337 CREATE2 deployment
├── SmartAccount.sol             → ERC-4337 account with passkey owner
├── EscrowVault.sol              → Payment Intent escrow system
├── BroPaymaster.sol             → Enhanced policy engine
└── GuardiansModule.sol          → Social recovery (optional)
```

## Development Phases

### Phase 1: Core Smart Contracts (Days 1-7)
**Status: PENDING**

#### 1.1 AccountFactory Contract
- [ ] ERC-4337 compatible factory
- [ ] CREATE2 deterministic deployment
- [ ] Integration with passkey-derived addresses
- [ ] Basic salt computation from phoneHash

#### 1.2 SmartAccount Contract  
- [ ] ERC-4337 BaseAccount implementation
- [ ] Passkey signature validation
- [ ] Owner key rotation mechanism
- [ ] Session key support (future)

#### 1.3 EscrowVault Contract
- [ ] Payment Intent creation (`create()`)
- [ ] Recipient binding with phoneHash + proof
- [ ] Release mechanism (`release()`)
- [ ] Revoke/refund with time windows
- [ ] Event emission for indexing

#### 1.4 Enhanced BroPaymaster
- [ ] ERC-4337 paymaster compliance  
- [ ] Basic policy validation (user whitelist)
- [ ] Gas limit enforcement
- [ ] Device attestation stub (mock for PoC)

### Phase 2: Identity & Authentication (Days 5-10)
**Status: PENDING**

#### 2.1 WebAuthn Integration
- [ ] Passkey creation flow in browser
- [ ] Signature generation for UserOps
- [ ] Public key extraction and mapping
- [ ] Fallback to software keys (demo)

#### 2.2 Phone Hash Binding System
- [ ] HMAC-based phone number hashing
- [ ] Recipient proof generation/verification
- [ ] Backend signature service (mock)
- [ ] Privacy-preserving binding validation

### Phase 3: Payment Capsules System (Days 8-14)
**Status: PENDING**

#### 3.1 Minimal Frontend (Next.js PWA)
- [ ] Payment Capsule UI components
- [ ] WebAuthn integration
- [ ] WhatsApp sharing simulation
- [ ] Balance display (USDC testnet)
- [ ] Send/Accept flow implementation

#### 3.2 JWS Intent Service
- [ ] Payment Intent JWS creation
- [ ] Anti-phishing signature verification
- [ ] OpenGraph metadata generation
- [ ] Revoke/expiry management
- [ ] Backend API endpoints

### Phase 4: Base Testnet Integration (Days 12-16)
**Status: PENDING**

#### 4.1 Deployment Infrastructure
- [ ] Base testnet configuration
- [ ] Bundler service integration (Stackup/Pimlico)
- [ ] USDC testnet token setup
- [ ] Gas funding for Paymaster
- [ ] Contract verification

#### 4.2 End-to-End Testing
- [ ] Complete send → accept flow
- [ ] Paymaster gas sponsorship
- [ ] Revoke/refund scenarios  
- [ ] Multi-user testing
- [ ] Performance benchmarking

## Technical Dependencies

### External Services (PoC)
- **Base Testnet**: Network + USDC token
- **ERC-4337 Bundler**: Stackup/Pimlico/Alchemy
- **WebAuthn**: Browser APIs (Chrome/Safari)
- **Backend**: Simple Express.js API server
- **Frontend**: Next.js with PWA capabilities

### Key Libraries/Frameworks
```json
{
  "contracts": {
    "eth-infinitism/account-abstraction": "^0.8.0",
    "@openzeppelin/contracts": "^5.3.0",
    "forge-std": "^1.9.6"
  },
  "frontend": {
    "next": "15.3.1", 
    "@simplewebauthn/browser": "^10.0.0",
    "jose": "^5.0.0"
  },
  "backend": {
    "express": "^4.19.0",
    "@simplewebauthn/server": "^10.0.0",
    "ethers": "^6.13.0"
  }
}
```

## Success Criteria

### Functional Requirements
- [ ] User can create passkey-secured account (no seed phrase)
- [ ] Sender can create Payment Intent via signed capsule
- [ ] Recipient can accept payment using passkey
- [ ] Paymaster sponsors gas for all transactions
- [ ] Revoke/refund mechanisms work within time windows
- [ ] Phone hash binding prevents unauthorized access

### Performance Targets (PoC)
- Capsule load time: < 2s (testnet)
- Account creation: < 5s 
- Payment acceptance: < 10s (including bundler)
- Gas cost per transaction: < $0.01 USD equivalent

### Security Validations
- [ ] Passkey signatures validate correctly
- [ ] Payment Intents cannot be double-spent
- [ ] Phone hash binding prevents theft
- [ ] Paymaster cannot be drained
- [ ] Time-based revoke/refund work correctly

## Risk Mitigation

### Technical Risks
- **ERC-4337 Bundler reliability**: Test multiple providers
- **WebAuthn browser support**: Fallback to software keys
- **Base testnet stability**: Monitor network status
- **Gas estimation accuracy**: Conservative limits + monitoring

### Development Risks  
- **Smart contract complexity**: Start minimal, iterate
- **Integration challenges**: Mock external services initially
- **Timeline pressure**: Focus on core flow, defer nice-to-haves

## Timeline: 16 Days

```
Week 1: Smart Contracts + WebAuthn basics
Week 2: Frontend integration + JWS system  
Week 3: Base testnet deployment + E2E testing
```

## Next Steps
1. Setup Base testnet environment
2. Create minimal AccountFactory contract
3. Implement basic SmartAccount with passkey validation
4. Build simplified EscrowVault for Payment Intents

---

**Status**: Ready to begin Phase 1 implementation
**Last Updated**: 2025-09-05