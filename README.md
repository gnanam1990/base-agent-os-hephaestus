# Hephaestus

> Autonomous smart contract forge. Part of the Base Agent OS.

![status](https://img.shields.io/badge/status-building-yellow)
![license](https://img.shields.io/badge/license-MIT-blue)

## Endpoints

| Method | Route | Price | Description |
|--------|-------|-------|-------------|
| POST | /api/deploy/standard | $20 | Deploy from template |
| POST | /api/deploy/custom | $1 | Preview custom deploy |
| POST | /api/deploy/custom/confirm | $99 | Confirm custom deploy |
| POST | /api/deploy/deep | $5 | Preview deep audit deploy |
| POST | /api/deploy/deep/confirm | $495 | Confirm deep audit deploy |
| GET | /api/jobs/:id | Free | Get job status |
| GET | /api/deploys/:addr | Free | Get on-chain deploy record |
| GET | /api/templates | Free | List available templates |
| POST | /api/refund/:job_id | Free | Request refund for failed job |
| GET | /health | Free | Health check |

## Quickstart

```bash
# Start the API server
pnpm --filter @hephaestus/server dev

# List templates
curl http://localhost:3031/api/templates

# Health check
curl http://localhost:3031/health
```

## On-chain

- **HephaestusRegistry** - Pending deployment (run `forge script script/Deploy.s.sol` with env vars)

## Part of the Base Agent OS

This agent is one of ten in the Base Agents portfolio:

- [Cassandra](https://github.com/gnanam1990/cassandra) - Polymarket->Base alpha pipeline
- [Hephaestus](https://github.com/gnanam1990/hephaestus) - Autonomous contract forge
- [Kratos](https://github.com/gnanam1990/kratos) - Adversarial stress-tester
- [Argus](https://github.com/gnanam1990/argus) - Onchain sentinel
- [Veritas](https://github.com/gnanam1990/veritas) - Farcaster fact-checker
- [Janus](https://github.com/gnanam1990/janus) - Cross-chain identity bridge
- [Oracle](https://github.com/gnanam1990/oracle) - Prediction-market-as-a-service
- [Surya](https://github.com/gnanam1990/surya) - Yield strategist
- [Mercurius](https://github.com/gnanam1990/mercurius) - Agent-to-agent broker
- [Ananta](https://github.com/gnanam1990/ananta) - Indian market localization

## License

MIT (c) 2026 Gnanam (kRATOS)
