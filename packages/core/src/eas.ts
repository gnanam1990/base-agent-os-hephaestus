/** EAS deployment addresses on Base mainnet (chainId 8453). */
export const EAS_BASE_ADDRESS = '0x4200000000000000000000000000000000000021' as const;
export const EAS_SCHEMA_REGISTRY_BASE = '0x4200000000000000000000000000000000000020' as const;

/** Hephaestus's primary EAS schema string. Register once via packages/eas-attest. */
export const PRIMARY_SCHEMA = 'address contractAddr, address requester, bytes32 specHash, uint8 auditTier, uint64 deployedAt' as const;
