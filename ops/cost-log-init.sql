PRAGMA journal_mode = WAL;
CREATE TABLE IF NOT EXISTS deploys (
    job_id TEXT PRIMARY KEY,
    requester TEXT,
    contract_address TEXT,
    tx_hash TEXT,
    gas_used INTEGER,
    gas_price_gwei REAL,
    eth_price_usd REAL,
    total_cost_usd REAL,
    audit_tier TEXT,
    timestamp INTEGER
);
