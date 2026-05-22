import { z } from 'zod';

export const AuditTierSchema = z.enum(['standard', 'kratos-deep']);
export type AuditTier = z.infer<typeof AuditTierSchema>;

export const JobStatusSchema = z.enum([
  'QUEUED', 'GENERATING', 'COMPILING', 'AUDITING', 'DEPLOYING',
  'VERIFYING', 'RECORDING', 'SUCCESS',
  'GENERATION_FAILED', 'COMPILE_FAILED', 'AUDIT_FAILED', 'DEPLOY_FAILED', 'VERIFY_FAILED'
]);
export type JobStatus = z.infer<typeof JobStatusSchema>;

export const DeployJobSchema = z.object({
  job_id: z.string(),
  requester: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  spec: z.string(),
  template_hint: z.string().optional(),
  constructor_args: z.array(z.any()).optional(),
  audit_tier: AuditTierSchema,
  payment_receipt: z.string(),
  created_at: z.number().int(),
});
export type DeployJob = z.infer<typeof DeployJobSchema>;

export const DeployResultSchema = z.object({
  job_id: z.string(),
  status: JobStatusSchema,
  contract_address: z.string().regex(/^0x[a-fA-F0-9]{40}$/).optional(),
  tx_hash: z.string().optional(),
  attestation_uid: z.string().optional(),
  abi: z.array(z.any()).optional(),
  error: z.string().optional(),
});
export type DeployResult = z.infer<typeof DeployResultSchema>;
