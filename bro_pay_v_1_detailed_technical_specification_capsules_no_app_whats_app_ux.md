# Bro Pay v1 — Detailed Technical Specification (Capsules, No‑App WhatsApp UX)

> **Mission:** Send money like a message. Zero install. Zero seed. Zero gas. EU‑grade compliance. On‑chain finality.

**Primary rail (v1):** Base L2 (OP‑stack)  
**Alternatives:** Ethereum L1 (vault-grade, expensive), zkSync Era (ultra‑low fees, longer proof finality)  
**Primary asset:** USDC (EUR display), optionally EURC where available

---

## 0) Scope, Goals, Non‑Goals

### Goals
- Native‑feeling WhatsApp experience via **signed Payment Capsules** opened in in‑app browser (no app install).
- **Non‑custodial by default** via Account Abstraction (ERC‑4337 smart accounts), **no seed phrases**.
- **Gasless UX** (Paymaster sponsorship); fiat‑first UI; crypto invisible for beginners.
- **Top‑up/Withdraw** via EU‑compatible rails (Open Banking PIS SEPA Instant; on/off‑ramp partners).
- **Undo/Refund/Expiry** safety net; disputes; anti‑phishing signed links.
- **Compliance**: progressive KYC/KYT/Travel Rule; GDPR‑first data model.

### Non‑Goals (v1)
- Multi‑chain bridging (future).  
- In‑chat mini‑apps published via WhatsApp store.  
- Complex DeFi features (swaps/yield).  

---

## 1) Personas & UX Tenets

- **Gen Z**: playful microcopy, emojis, haptics, instant gratification; default simple flows.  
- **Adults/Seniors**: large type, high contrast, plain language, explicit confirmations, clear fees & ETAs.  
- **Power users**: Advanced menu (external wallet, WC), detailed tx info hidden by default.

**Tenets:** fiat‑first display; 1 action per screen; never say “gas, seed, hash” unless user taps “Details”.

---

## 2) High‑Level Architecture

```
User ──WhatsApp link──▶ Capsule (PWA in in‑app browser)
                        │  
                        ├─▶ Auth & Identity (WebAuthn passkeys, phone OTP, device attestation)
                        │
                        ├─▶ Intent Service (JWS sign/verify, OG cards, revoke/expiry)
                        │
                        ├─▶ Wallet Orchestrator (ERC‑4337 bundler, Paymaster policy, AA session keys)
                        │
                        ├─▶ Smart Contracts (AccountFactory, EscrowVault, BroPaymaster, GuardiansModule)
                        │
                        ├─▶ Compliance (KYC/KYT/Travel Rule, risk/velocity)
                        │
                        ├─▶ Fiat Rails (Open Banking PIS, Ramp/Transak/MoonPay adapters)
                        │
                        └─▶ Observability (events indexer, logs/metrics, alerting)
```

Infra: EU regions (Frankfurt/Dublin), CDN edge for capsules, HSM/KMS for Paymaster/relayer keys.

---

## 3) Smart Contract Suite (Base chain, EVM)

### 3.1 Contracts & Responsibilities
- **AccountFactory** (CREATE2): Deterministic deployment of AA smart accounts.  
- **SmartAccount** (ERC‑4337 compatible): owner = user’s on‑chain key (mapped from passkey via off‑chain signature). Modules: guardian recovery, daily spend limits.  
- **EscrowVault**: Holds USDC per Payment Intent, enforces recipient binding & timers (undo/expiry).  
- **BroPaymaster**: Sponsors gas for allowed methods subject to policy (KYC tier, velocity, device attestation).  
- **GuardiansModule**: Social recovery; rotate owner key with guardian approval/time‑lock.

### 3.2 Minimal ABIs (sketch)
```solidity
interface IAccountFactory {
  function computeAddress(bytes32 salt) external view returns (address);
  function deploy(bytes32 salt, bytes calldata initData) external returns (address);
}

interface IEscrowVault {
  struct Intent {address sender; bytes32 recipHash; uint256 amount; uint64 createdAt; uint64 expiry; bool released; bool revoked;}
  function create(bytes32 intentId, address sender, bytes32 recipHash, uint256 amount, uint64 expiry) external;
  function release(bytes32 intentId, address recipientAccount, bytes calldata recipProof) external;
  function revoke(bytes32 intentId) external; // sender only within window
  function refund(bytes32 intentId) external; // after expiry
  event EscrowFunded(bytes32 indexed intentId, address indexed sender, uint256 amount);
  event EscrowReleased(bytes32 indexed intentId, address indexed recipient, uint256 amount);
  event EscrowRevoked(bytes32 indexed intentId);
  event EscrowRefunded(bytes32 indexed intentId);
}

interface IBroPaymaster {
  function setPolicy(bytes calldata policy) external; // admin only
  function sponsor(bytes calldata userOp, bytes calldata attestation) external returns (bool);
}
```

### 3.3 Security Invariants
- Vault can release only if `(intentId exists) && (!released&&!revoked) && (now <= expiry) && recipProof binds phoneHash→recipientAccount owner`.
- Revoke allowed only by original sender and only within `revocableFor` window.
- Refund allowed by anyone after `expiry` (no fee v1).
- Paymaster only sponsors whitelisted methods; enforces user/device allow‑list & risk/velocity caps.

---

## 4) Identity, Auth, and Binding

### 4.1 Passkeys (WebAuthn)
- **Create** on first capsule open. Store publicKey + attestation result server‑side. No seed phrase.  
- **Sign‑in** via WebAuthn `get()`. Fallback: SMS OTP → ephemeral software key (prompt upgrade later).

### 4.2 Phone Number Binding
- Collect/confirm `phoneE164` via silent link (deep link param) or OTP.  
- Store only **phoneHash** (e.g., `HMAC(salt, E164)`) for on‑chain binding.  
- `recipProof` in `release()` encodes a Bro‑signed assertion mapping recipient account owner key ↔ phoneHash at acceptance time.

### 4.3 Device Attestation
- Android Play Integrity / iOS DeviceCheck token required for Paymaster sponsorship. Cache device reputation in risk engine.

---

## 5) Payment Capsules (Signed Links)

### 5.1 JWS Payload
```json
{
  "typ": "bro/int",
  "alg": "ES256",
  "kid": "bro-prod-2025-09",
  "payload": {
    "ver": 1,
    "intentId": "pi_9r3a...c2",
    "asset": "USDC",
    "fiat": {"ccy": "EUR", "amount": "10.00", "fx": "0.9993"},
    "usdc": "10.01",
    "chain": "base",
    "to": {"phoneHash": "0x…"},
    "from": {"display": "Luca", "avatarUrl": "…"},
    "rights": {"revocableFor": 600, "oneTime": true},
    "expiry": "2025-09-05T10:12:00Z"
  }
}
```

### 5.2 Anti‑Phishing Measures
- SXG‑style signature reveal, domain pinning, HSTS preload, short TTL, one‑time redeem.
- Capsule bound to `phoneHash` and **requires passkey** → link theft useless.

---

## 6) End‑to‑End Flows (Exact)

### 6.1 Wallet Provisioning (first open)
1. Capsule loads → prompt **Create secure key** → WebAuthn `create()`.
2. Backend verifies attestation, stores `passkeyPublicKey`, computes `salt = H(phoneHash)`; returns predicted `accountAddress = factory.computeAddress(salt)`.
3. No on‑chain deploy yet (lazy deploy on first spend/accept).

### 6.2 Send Money
1. Sender opens Send sheet (PWA share target) → inputs amount & recipient.  
2. `POST /intents` → FX quote, risk/KYT, create JWS, prepare escrow.  
3. If sender **needs top‑up** → go to 6.4, then resume.  
4. Bundler executes `EscrowVault.create` funding from sender account; Paymaster sponsors.
5. Capsule link (OG card) is pasted into WhatsApp chat.

### 6.3 Accept Money
1. Recipient taps link → sees **Accept €X**.  
2. First‑time: create passkey, OTP to bind phone.  
3. `POST /intents/:id/accept` → backend checks JWS, tiers, deploy account if needed.  
4. Bundler calls `release(intentId, recipientAccount, recipProof)`.
5. Success toast; balance updated.

### 6.4 Top‑Up (Card / SEPA Instant)
- **Card**: Open on‑ramp sheet (provider SDK) prefilled (network=Base, asset=USDC, amount incl. buffer). On success webhook, credit sender account → resume 6.2.
- **SEPA Instant**: Open Banking PIS to EMI account; upon confirmation, mint/transfer USDC to sender account → resume.

### 6.5 Withdraw
1. User picks **Withdraw** → IBAN or bank connect.  
2. `POST /withdrawals` → if PIS payout available, trigger instant A2A; else sell USDC via off‑ramp → payout.  
3. Transfer USDC from user account to payout wallet (Paymaster).  
4. Show ETA & receipt; timeline entry created.

### 6.6 Undo / Expiry
- **Undo** within window: `POST /intents/:id/revoke` → bundler `revoke()`; OG card updates to Cancelled.
- **Expiry**: anyone may `refund()` → returns to sender; capsule shows Expired.

### 6.7 Dispute
- **Report** → state = HOLD; vault blocks outbound (if still in escrow).  
- Agent resolves → on‑chain release/refund; rate‑limit abusers.

### 6.8 External Wallet (Advanced)
- WalletConnect / address input; `transfer` from smart account; Paymaster sponsor if policy ok.

### 6.9 Recovery
- New device: login (phone) → passkey missing → options: Guardian co‑sign, Cloud passkey sync, or KYC reset → rotate owner key via GuardiansModule.

---

## 7) Back‑End Services & Data

### 7.1 Services
- **API Gateway**: Fastify/NestJS; JWT auth; mTLS to microservices.  
- **Intent Service**: create/verify JWS, OG metadata, revoke/expiry timers.  
- **Wallet Orchestrator**: 4337 bundler, Paymaster policy engine, device attest verification.  
- **Compliance**: KYC (Sumsub/Onfido), KYT (Chainalysis/TRM), Travel Rule (Notabene).  
- **Fiat Service**: Open Banking (TrueLayer/Tink) + on/off‑ramp (Ramp/Transak/MoonPay).  
- **Indexer**: Subscribes to contract events; reconciles balances; triggers notifications.  
- **Notifications**: Email (SendGrid), optional SMS, web push (PWA).

### 7.2 Data Model (Postgres)
- `users(id, phone_hash, passkey_pub, kyc_status, tier, created_at, locale, risk_score)`
- `devices(id, user_id, attestation_score, last_seen, reputation)`
- `accounts(user_id, chain, address, deployed, guardian_addr, spend_limit_daily)`
- `intents(id, sender_user_id, recip_phone_hash, asset, fiat_ccy, fiat_amount, usdc_amount, fx, rights, expiry, state, created_at)`
- `intents_events(id, intent_id, type, tx_hash, meta, created_at)`
- `withdrawals(id, user_id, iban_masked, amount_eur, fee_eur, provider, status, eta, created_at)`
- `kyc(id, user_id, provider, level, status, pii_ref, updated_at)`
- `risk_log(id, user_id, signal, score, meta, created_at)`

### 7.3 Caching & Rate Limits (Redis)
- `rate:user:{id}` buckets (send/accept/withdraw).  
- Idempotency keys per API call (`idem:{hash}` ttl 24h).  
- Recent quotes cache (`fx:USDC:EUR`).

---

## 8) Public API (v1)

```http
POST /v1/wallets
→ { accountAddress, deployed }

POST /v1/intents
{ toPhoneE164, fiat:{ccy,amount}, asset:"USDC", undoWindowSec }
→ { intentId, capsuleUrl, quote:{usdc,fx}, expiresAt }

POST /v1/intents/:id/accept
→ { status:"released", txHash, balance:{eur,usdc} }

POST /v1/intents/:id/revoke
→ { status:"revoked" }

GET  /v1/balances
→ { eur, usdc, pendingIntents:[...] }

POST /v1/withdrawals
{ amountEUR, iban | bankProviderToken }
→ { withdrawalId, feeEUR, eta, status }

GET  /v1/intents/:id
→ { state, amounts, parties, timestamps, onchain:{txs[]} }
```

Errors: JSON with `code`, `message`, optional `hint`. Common: `RATE_LIMITED`, `KYC_REQUIRED`, `RISK_BLOCKED`, `INTENT_EXPIRED`, `ALREADY_ACCEPTED`.

---

## 9) Compliance, Limits, Policy

- **Tiers**:  
  T0: Receive ≤ €150 lifetime; no off‑ramp.  
  T1: KYC‑Lite → ≤ €1,000/month; withdraw ≤ €500/day.  
  T2: Full KYC → higher limits (per partner policy).  
- **KYT**: screen counterparties > €100; block sanctioned addresses; log alerts.  
- **Travel Rule**: share originator/beneficiary when > €1,000 and destination is VASP; store evidence records.  
- **GDPR**: data minimization; PII in separate schema; encryption at rest; deletion on request; DPA with providers.

---

## 10) Fees, Pricing, Treasury

- Display one **Network & Payment Fee** line; domestic target €0–0.10; cross‑border target ≤ 0.75% all‑in.  
- Treasury: maintain USDC float + ETH (gas) on Base; auto‑refill Paymaster; hedge FX exposure.

---

## 11) Performance & SLOs

- Capsule TTI < 300 ms (p95).  
- Accept click → L2 inclusion < 2 s (p90).  
- API availability ≥ 99.95%.  
- Paymaster sponsorship success ≥ 99.9%.

---

## 12) Security Model & Threats

- **Key theft**: mitigated by passkeys + device attestation + guardian recovery.  
- **Phishing**: signed capsules, domain pinning, verified card UI.  
- **Replay**: one‑time intents with expiry and JTI.  
- **Link leak**: phoneHash + passkey required to accept.  
- **DoS**: rate limits, circuit breakers, queue UserOps when sequencer degraded.  
- **Contract risk**: audits, formal specs for Escrow invariants, pause/upgrade via Security Council w/ timelock.

---

## 13) Accessibility & Localization

- **Senior Mode** toggle: ≥18pt, high contrast, icon labels.  
- Localize copy (EN, IT, ES, DE, FR); RTL support.  
- Clear fee/ETA language; “why blocked?” explanations.

---

## 14) Rollout Plan

- **Alpha (Weeks 1–8)**: internal + 100 beta users; corridors: EU→EU.  
- **Beta (Weeks 9–16)**: 2–3 EU countries; enable SEPA Instant; refine fees.  
- **v1 Launch**: open waitlist → invite waves; add cross‑border corridors.

---

## 15) Chain Options — Deltas

### Ethereum L1
- **Pros**: maximum decentralization/security.  
- **Cons**: fees volatile/high; slower UX; Paymaster spend heavy.  
- **Use**: high‑value vaults; corporate settlements.

### Base (Recommended v1)
- **Pros**: ultra‑low fees, fast, EVM‑native; broad on/off‑ramp support; ETH gas; Coinbase ecosystem.  
- **Cons**: sequencer trust until L1 finalize; still decentralizing.

### zkSync Era
- **Pros**: lowest fees; cryptographic validity; token‑agnostic gas.  
- **Cons**: proof finality 15–180 min; some tooling quirks.  
- **Use**: cost‑sensitive corridors once UX proven.

---

## 16) QA & Testing

- **Contracts**: unit tests, fuzzing (foundry/echidna), invariant checks (escrow cannot leak funds).  
- **Backend**: property tests (idempotency), chaos tests (sequencer down), KYT mocks.  
- **E2E**: Cypress mobile emulation, WebAuthn mock, provider sandbox flows.  
- **Security**: static analysis (Slither), SAST/DAST, bounty program.

---

## 17) DevOps & Secrets

- IaC (Terraform), blue/green deploys, canary for Paymaster.  
- Secrets in KMS; key rotation; HSM for Paymaster/relayer.  
- Observability: OpenTelemetry, dashboards (latency, sponsorship rate, revert reasons).

---

## 18) Copy Library (selected)

- **Welcome**: “Secure your money with your phone. No passwords, no seed phrases.”  
- **Send**: “Enter amount in € and choose who to pay.”  
- **Accept**: “You’ve received **€{amount}** from {name}. Tap to add to your balance.”  
- **Withdraw**: “Withdraw to your bank. You receive **€{net}** (fee **€{fee}**).”  
- **Limits**: “To protect you, new accounts can receive up to €150. Verify to increase.”

---

## 19) Open Questions (to track)
- Optimal guardian UX vs. passkey‑only for recovery.  
- PhoneHash on‑chain binding pattern (registry vs. ZK proof) privacy trade‑offs.  
- Best default off‑ramp partners per EU market (coverage/fees).

---

**Appendix A — Sequence Diagrams (text)**

**Send (with balance)**
1. UI: amount+recipient → POST /intents  
2. Svc: quote, risk → UserOp: vault.create → emit EscrowFunded  
3. UI: paste capsule in chat

**Accept**
1. UI: passkey sign session → POST /intents/:id/accept  
2. Svc: deploy account if needed → UserOp: vault.release → emit EscrowReleased  
3. UI: success, balance++

**Withdraw**
1. UI: IBAN → POST /withdrawals  
2. Svc: PIS payout or off‑ramp; on‑chain transfer to payout wallet  
3. UI: receipt, ETA

---

**Appendix B — Risk & Velocity Defaults**
- New device/day: max 3 sends, €50/day cap.  
- Post‑Tier1: €1,000/month; per‑tx max €250.  
- Post‑Tier2: €5,000/day; per‑tx max €2,000.  
- Paymaster gas cap/user/day: €0.50.

---

**End of Spec**

