export const hephaestusRegistryAbi = [
  {
    type: 'function',
    name: 'setAgent',
    inputs: [{ name: 'newAgent', type: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'recordDeploy',
    inputs: [
      { name: 'contractAddr', type: 'address' },
      { name: 'requester', type: 'address' },
      { name: 'specHash', type: 'bytes32' },
      { name: 'auditTier', type: 'uint8' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getDeployRecord',
    inputs: [{ name: 'contractAddr', type: 'address' }],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'contractAddr', type: 'address' },
          { name: 'requester', type: 'address' },
          { name: 'specHash', type: 'bytes32' },
          { name: 'deployedAt', type: 'uint64' },
          { name: 'attestationUID', type: 'bytes32' },
          { name: 'auditTier', type: 'uint8' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getDeploysByRequester',
    inputs: [{ name: 'requester', type: 'address' }],
    outputs: [{ name: '', type: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'deploys',
    inputs: [{ name: '', type: 'address' }],
    outputs: [
      { name: 'contractAddr', type: 'address' },
      { name: 'requester', type: 'address' },
      { name: 'specHash', type: 'bytes32' },
      { name: 'deployedAt', type: 'uint64' },
      { name: 'attestationUID', type: 'bytes32' },
      { name: 'auditTier', type: 'uint8' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'agent',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'totalDeploys',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'DeployRecorded',
    inputs: [
      { name: 'contractAddr', type: 'address', indexed: true },
      { name: 'requester', type: 'address', indexed: true },
      { name: 'auditTier', type: 'uint8', indexed: false },
    ],
  },
] as const;
