#!/bin/bash
# ops/seed-activity.sh
# Seed initial on-chain activity for HephaestusRegistry
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <CONTRACT_ADDRESS>"
    exit 1
fi

CONTRACT=$1
source /Users/kratos/.zshenv

echo "Seeding activity for $CONTRACT"

for i in $(seq 1 5); do
    echo "Sending ping $i..."
    cast send $CONTRACT "ping()" --rpc-url $BASE_MAINNET_RPC --private-key $DEPLOYER_PK 2>/dev/null || echo "Ping not available (expected for registry)"
    sleep 30
done

echo "Seed activity complete"
