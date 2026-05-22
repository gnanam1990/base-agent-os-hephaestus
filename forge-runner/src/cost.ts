import Database from 'better-sqlite3';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_PATH = path.join(__dirname, '..', '..', 'ops', 'hephaestus-cost.db');

let db: Database.Database | null = null;

function getDb(): Database.Database {
    if (!db) {
        db = new Database(DB_PATH);
        db.pragma('journal_mode = WAL');
        db.exec(`
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
            )
        `);
    }
    return db;
}

export async function logDeploy(data: {
    job_id: string;
    requester: string;
    contract_address: string;
    tx_hash: string;
    audit_tier: string;
}) {
    const database = getDb();
    const ethPrice = parseFloat(process.env.ETH_PRICE_USD || '3000');

    database.prepare(`
        INSERT OR REPLACE INTO deploys (job_id, requester, contract_address, tx_hash, audit_tier, timestamp, eth_price_usd)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
        data.job_id,
        data.requester,
        data.contract_address,
        data.tx_hash,
        data.audit_tier,
        Math.floor(Date.now() / 1000),
        ethPrice
    );
}
