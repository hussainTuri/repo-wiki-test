# ADR 004: AWS SDK Bundling (Keep Everything Explicit)

## Status
Accepted

## Context
Lambda’s Node.js runtime historically shipped only AWS SDK v2; it now also exposes a baseline AWS SDK v3 version. We still explicitly bundle our own pinned v3 clients (`@aws-sdk/*`) for predictable versions, tree‑shaking and consistent local vs production behavior.

## Decision
Always import the specific AWS SDK v3 clients we need and bundle them with esbuild. Do not rely on the runtime’s global AWS SDK. List the AWS SDK packages explicitly in the package manifest `dependencies` so they are present; ensure esbuild includes them (do not mark `@aws-sdk/*` as external).

## Why (Summary)
- Predictable versions (we choose when to upgrade).
- Smaller code surface (only used clients end up in the bundle).
- Same code path everywhere (local, CI, prod).
- Easier security patching and auditing.

## How
1. Add required `@aws-sdk/client-*` (and optionally `@aws-sdk/lib-dynamodb`) to the Lambda package `dependencies`.
2. esbuild config: `bundle: true`, do not exclude `@aws-sdk/*`.
3. Deploy the single bundled file.
4. Use `@types/aws-lambda` only for handler typings.

Example:
```ts
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
```

## Consequences
Positive:
- Controlled upgrades and predictable behavior.
- Reduced cognitive load: one SDK style.

Costs / Trade-offs:
- Slight bundle size increase vs implicit runtime v3.

## Date
2025-09-19