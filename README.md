# Hephaestus

> Autonomous smart-contract forge: pay-per-use API that generates, compiles, audits, and deploys Solidity contracts to Base. Part of the Base Agent OS.

![license](https://img.shields.io/badge/license-MIT-blue)
![CI](https://github.com/gnanam1990/base-agent-os-hephaestus/actions/workflows/ci.yml/badge.svg)

## Overview

Hephaestus is an autonomous forge for EVM smart contracts. A paid HTTP API accepts
either a template selection or a free-text spec, enqueues a deploy job, and a
background runner walks the contract through a full pipeline — generate, compile,
static-audit, deploy to Base, verify on the explorer, and attest the result via
EAS — recording each deployment in an on-chain registry. Payments are collected
inline through the x402 HTTP payment protocol. It is one agent in the Base Agent
OS portfolio.

## Features

- **Paid deploy API** — Hono server with five priced deploy endpoints plus free
  query/health routes; pricing enforced by x402 payment middleware on `/api/deploy/*`.
- **Template library** — 10 audited Foundry templates (ERC-20, ERC-721, ERC-4626
  vault, vesting, payment splitter, Dutch auction, Merkle airdrop, 3-of-5 multisig,
  timelock, NFT royalty splitter), each with Solidity source and a test.
- **Spec-to-contract generation** — multi-model codegen with a voting/consensus
  step: candidate sources are compiled with `forge build` and screened with
  Slither; a consensus or shortest-compiling candidate wins.
- **Job pipeline** — Redis Streams queue feeding a concurrent runner that tracks
  per-job status (`GENERATING` → `COMPILING` → `AUDITING` → `DEPLOYING` →
  `VERIFYING` → `RECORDING` → `SUCCESS`).
- **On-chain registry & royalties** — `HephaestusRegistry` records deploy metadata;
  `HephaestusRoyalty` splits forwarded fees (5% treasury / 95% originator).
- **EAS attestations** — each successful deploy is attested on Base via the
  Ethereum Attestation Service.
- **Two-step previews** — custom and deep-audit tiers return an HMAC-signed,
  expiring preview token that must be confirmed (and paid for) to enqueue a job.
- **Cost logging** — local SQLite ledger of deploy records and cost inputs.

## Tech stack

- **API / runner:** TypeScript, Hono, `@hono/node-server`, Redis (Streams),
  ethers, Zod, x402 (`x402-hono`, `@coinbase/x402`)
- **Codegen:** TypeScript with pluggable LLM providers, Slither static analysis
- **Contracts:** Solidity 0.8.24, Foundry (forge), OpenZeppelin Contracts
- **Attestations:** Ethereum Attestation Service SDK (`eas-sdk`)
- **Storage:** Redis (queue/status), better-sqlite3 (cost ledger)
- **Tooling:** pnpm workspaces (pnpm 9), Node 20

## Architecture

A pnpm monorepo. The server only enqueues; the runner does the work.

| Path | Role |
|------|------|
| `server/` | Hono API: priced deploy endpoints (x402), job/deploy/template queries, refunds, `/health`, `/openapi.json`. |
| `forge-runner/` | Background worker consuming the `hephaestus:jobs` Redis stream; runs the full generate→deploy→attest pipeline and writes job status. |
| `packages/core/` | Shared types, helpers, EAS constants, and the registry ABI. |
| `packages/llm-codegen/` | Spec→Solidity generation with multi-model candidate voting and compile/Slither screening. |
| `packages/eas-attest/` | Thin wrapper over the EAS SDK for posting attestations. |
| `contracts/` | Foundry project: `HephaestusRegistry` + `HephaestusRoyalty`, deploy script, tests. |
| `templates/` | Foundry project holding the 10 deployable contract templates, an `index.json` catalog, and tests. |
| `ops/` | SQL/seed helpers and a `deployments.json` address manifest (placeholders until deployed). |

## Getting started

### Prerequisites

- Node 20 and pnpm 9
- [Foundry](https://book.getfoundry.sh/) (`forge`) on `PATH` — required by both the
  runner pipeline and the contract/template builds
- A reachable Redis instance (for the API and runner)
- Optional: [Slither](https://github.com/crytic/slither) for the audit step (the
  pipeline continues if it is not installed)

### Installation

```bash
git clone --recurse-submodules https://github.com/gnanam1990/base-agent-os-hephaestus.git
cd base-agent-os-hephaestus
pnpm install
# if you cloned without submodules:
git submodule update --init --recursive
```

### Configuration

Copy `.env.example` and fill in the values you need. Variable names read by the code:

| Variable | Purpose |
|----------|---------|
| `BASE_MAINNET_RPC` | Base mainnet RPC endpoint (deploys, registry reads, attestations). |
| `BASESCAN_API_KEY` | Explorer API key used for `forge verify-contract`. |
| `DEPLOYER_PK` | Private key used to deploy contracts and (fallback) sign attestations. |
| `AGENT_PK` | Private key used to sign EAS attestations. |
| `AGENT_WALLET` | Wallet that receives x402 payments; also the registry's authorized agent. |
| `HEPHAESTUS_REGISTRY_ADDR` | Deployed `HephaestusRegistry` address (for `/api/deploys/:addr`). |
| `HEPHAESTUS_ROYALTY_ADDR` | Deployed `HephaestusRoyalty` address. |
| `EAS_SCHEMA_UID_DEPLOY` | EAS schema UID used when attesting deploys. |
| `REDIS_URL` | Redis connection URL (queue + job status). |
| `PORT_API` | API listen port (defaults to `3031`). |
| `PREVIEW_HMAC_SECRET` | HMAC key for signing/verifying custom & deep preview tokens. |
| `ETH_PRICE_USD` | ETH price used by the cost ledger (defaults to `3000`). |
| `KRATOS_URL` | URL of the Kratos audit agent (deep-audit tier). |
| `TELEGRAM_WEBHOOK` | Optional notification webhook. |

Provider API keys for the codegen step are read from the environment by the
respective LLM SDKs (see `.env.example` for the expected names). Never commit
real secret values.

### Running

```bash
# API server (defaults to port 3031)
pnpm --filter @hephaestus/server dev

# Background job runner (separate process)
pnpm --filter @hephaestus/forge-runner start

# Build / typecheck the whole workspace
pnpm build
pnpm typecheck

# Build / test the contracts
cd contracts && forge build && forge test

# Build / test the templates
cd templates && forge build && forge test
```

Deploy the registry to Base with the Foundry script (requires `DEPLOYER_PK` and
`AGENT_WALLET`):

```bash
cd contracts
forge script script/Deploy.s.sol --rpc-url "$BASE_MAINNET_RPC" --broadcast
```

## Usage

### Endpoints

| Method | Route | Price | Description |
|--------|-------|-------|-------------|
| POST | `/api/deploy/standard` | $20.00 | Enqueue a deploy from a template (`template_hint`) or spec. |
| POST | `/api/deploy/custom` | $1.00 | Preview a custom spec; returns a signed preview token. |
| POST | `/api/deploy/custom/confirm` | $99.00 | Confirm a custom preview and enqueue the job. |
| POST | `/api/deploy/deep` | $5.00 | Preview a deep-audit deploy; returns a preview token. |
| POST | `/api/deploy/deep/confirm` | $495.00 | Confirm a deep-audit preview and enqueue the job. |
| GET | `/api/jobs/:id` | Free | Job status and result. |
| GET | `/api/deploys/:addr` | Free | On-chain deploy record from the registry. |
| GET | `/api/templates` | Free | List available templates. |
| POST | `/api/refund/:job_id` | Free | Issue a refund voucher for a failed job. |
| GET | `/health` | Free | Health check. |
| GET | `/openapi.json` | Free | OpenAPI description. |

`/api/deploy/*` routes are gated by x402 payment middleware; calls without a valid
on-chain payment are rejected before reaching the handler.

```bash
# List templates
curl http://localhost:3031/api/templates

# Health check
curl http://localhost:3031/health

# Enqueue a standard deploy from a template (requires x402 payment headers)
curl -X POST http://localhost:3031/api/deploy/standard \
  -H 'Content-Type: application/json' \
  -d '{"template_hint":"erc20-mintable/ERC20Mintable.sol","constructor_args":["Token","TKN"]}'

# Poll job status
curl http://localhost:3031/api/jobs/<job_id>
```

## Testing

- TypeScript: `pnpm test` (runs each package's `test` script; currently the
  `@hephaestus/llm-codegen` Vitest suite for the voting logic).
- Contracts: `forge test` in `contracts/` (registry and royalty tests).
- Templates: `forge test` in `templates/` (one test per template).

CI (`.github/workflows/ci.yml`) builds and typechecks the TypeScript packages and
runs both Foundry test suites on every push and pull request to `main`.

## Status

Early MVP / pre-deployment. The API, job queue, runner pipeline, templates, and
contracts are implemented and the codegen voting logic is unit-tested. The
contracts are **not yet deployed** — `ops/deployments.json` and the
`HEPHAESTUS_REGISTRY_ADDR` / `HEPHAESTUS_ROYALTY_ADDR` env vars hold placeholders
until a deploy is performed. Custom and deep previews currently return illustrative
capability/summary fields rather than full spec analysis, the refund flow issues a
voucher to a Redis stream (no automatic on-chain refund), and the live pipeline
depends on `forge` (and optionally Slither) being installed in the runner
environment.

## Part of the Base Agent OS

One of ten agents in the Base Agents portfolio:

- [Cassandra](https://github.com/gnanam1990/cassandra) — Polymarket → Base alpha pipeline
- [Hephaestus](https://github.com/gnanam1990/hephaestus) — Autonomous contract forge
- [Kratos](https://github.com/gnanam1990/kratos) — Adversarial stress-tester
- [Argus](https://github.com/gnanam1990/argus) — Onchain sentinel
- [Veritas](https://github.com/gnanam1990/veritas) — Farcaster fact-checker
- [Janus](https://github.com/gnanam1990/janus) — Cross-chain identity bridge
- [Oracle](https://github.com/gnanam1990/oracle) — Prediction-market-as-a-service
- [Surya](https://github.com/gnanam1990/surya) — Yield strategist
- [Mercurius](https://github.com/gnanam1990/mercurius) — Agent-to-agent broker
- [Ananta](https://github.com/gnanam1990/ananta) — Indian market localization

## License

MIT — see [LICENSE](LICENSE).
