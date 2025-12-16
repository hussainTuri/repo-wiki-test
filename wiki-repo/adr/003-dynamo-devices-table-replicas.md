# ADR 003: DynamoDB Devices Table Replicas

## Status
Accepted

## Context
The `devices` table stores registered user devices (tokens, platform metadata) used by multiple lambdas (e.g. register-device, push).  
Current usage is only in one AWS region (eu-west-1). We have not activated any additional DynamoDB Global Table replicas, so effectively the table is single‑region. No GSIs exist on any replica (because there are no replicas yet). When/if we add a replica we must decide whether to create the same GSIs there; if we do not, queries that rely on those GSIs would still have to route back to the primary region, removing most of the latency benefit of having a replica.

## Decision
Operate the `devices` DynamoDB table in a single region (eu-west-1) with required GSIs; do not enable Global Table replicas at this stage.  
Enable PITR on the table for data protection (covers the base table data; GSIs are logically reconstructed from the base table state during restore), already enabled for primary table.
Revisit replicas only when multi-region latency, regulatory, or RTO/RPO requirements justify the added cost and complexity.

## Consequences
Current decision (remain single region with PITR) has no new operational change today—this simply confirms the status quo. Below we list what materially changes ONLY if we later add replica regions.

### If We Add Replicas (Future Impact)
Positive:
- Lower read/write latency for users near new regions.
- Faster failover (potentially minutes) and smaller RPO (seconds of replication lag).

Negative:
- Higher write cost (each write replicated to every region + GSI cost per region if GSIs are created everywhere).
- Added operational complexity (multi-region deployments, replication lag monitoring, conflict resolution readiness—even if last-writer-wins by timestamp).
- Slower schema/index changes (must propagate safely across regions).

## Date
2025-09-19
