<!-- .github/header.png  →  Add your own 1200 × 400 hero image here -->
<p align="center">
  <img src=".github/header.png" width="100%" alt="BroPay – pay your bros in one tap"/>
</p>

<div align="center">

![CI](https://img.shields.io/github/actions/workflow/status/your‑org/bropay/ci.yml?label=CI)
![License](https://img.shields.io/badge/license-MIT-green)
![Foundry](https://img.shields.io/badge/Smart Contracts-Foundry-blue)
![Next.js 15](https://img.shields.io/badge/Web-Next.js%2015-black)
![Expo](https://img.shields.io/badge/Mobile-Expo%20Go-yellow)

</div>

---

# 🤑 BroPay

Send **€ EURC** or **$ USDC** to any phone contact inside WhatsApp (or
any messenger (comming next)) in **two taps** – no gas, no seed phrases.

* Self‑custodial (ERC‑4337 wallets on **Base**)
* Sender can top‑up with **card or open‑banking** in‑flow
* Receiver decides: keep, swap, or **cash‑out to SEPA / PayPal**
* Links auto‑refund after **7 days** if un‑claimed

> **Live on:** Base Sepolia (testnet)

---

## Prerequisites
* `pnpm` ≥ 8
* `node` ≥ 18
* `rust`
* `foundry`

```bash
npm install -g pnpm

curl -L https://foundry.paradigm.xyz | bash && foundryup

npm instal -g expo-cli
```

## 📁 Repo layout

bropay 
├─ packages/ 
│  ├─ contracts/ ← Foundry + OZ‑Upgrades contracts 
│  ├─ web/ ← Next.js 15 PWA + API 
│  └─ mobile/ ← React‑Native (Expo) wallet 
├─ .env.example 
├─ .gitignore 
└─ README.md


---

## ⚡️ Quick start

```bash
git clone https://github.com/olich97/bropay
cd bropay
cp .env.example .env          # fill RPC & keys
pnpm i                        # installs all workspaces

# 1. Contracts
cd packages/contracts
forge test -vv
forge script script/Deploy.s.sol \
     --rpc-url basesepolia \
     --broadcast --verify

# 2. Web
cd ../web
pnpm dev            # http://localhost:3000

# 3. Mobile
cd ../mobile
pnpm i
expo start          # scan QR on two phones

```

---

## 🏗️ Dev scripts

```bash
pnpm dev:web # Next.js dev server
pnpm dev:contracts # Local Anvil node + hot‑reload Forge
pnpm test # Runs Forge tests + Next lint
pnpm mobile # Starts Expo in packages/mobile
```

## 🔒 Security & upgrades

- UUPS proxies via openzeppelin/foundry‑upgrades
- Contract upgrades → forge script script/Upgrade*.s.sol --broadcast
- Secrets (JWT_SECRET, Stripe keys) stored in Cloudflare & mobile .env

## 🗺️ Roadmap

PRs welcome!
Run forge fmt && pnpm lint before pushing.

