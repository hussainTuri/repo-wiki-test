# ADR 005: Endpoint Status Processor Does Not Retry Failed Lambda Executions

## Status
Proposed

## Context
The endpoint-status-processor Lambda processes SQS messages to disable devices in DynamoDB when SNS endpoints are marked as disabled. When a Lambda execution fails (e.g., DynamoDB update fails, conditional check fails, or unexpected errors occur), we must decide whether to throw errors and return the message to the queue for retry or log the failure and move on.

If we throw errors, the message returns to the SQS queue and retries multiple times, potentially causing unnecessary load and duplicated work. However, if the SNS endpoint remains disabled, the push Lambda will continue sending new messages to the queue for the same device, providing natural retry opportunities.

## Decision
The endpoint-status-processor Lambda does not throw errors for failed executions. Instead, it logs the failure and continues processing other messages. The decision is based on the following reasoning:

1. **Natural Retry Mechanism**: If the push notification system continues to encounter the disabled endpoint, it will send new messages to the queue. The processor will eventually succeed when conditions are met.
2. **Avoid Unnecessary Load**: Retrying the same message multiple times may not resolve transient issues and increases DynamoDB and SQS load.
3. **Idempotency**: The atomic DynamoDB update with ConditionExpression ensures only valid updates succeed. Duplicate or stale messages are safely ignored.
4. **Observability**: All failures are logged with full context, enabling monitoring and alerting for recurring issues.

## Consequences
- **Positive**:
  - Reduced SQS retry load and Lambda execution time.
  - Simpler error handling logic.
  - Failed messages do not block processing of other messages.
  - Natural retry from upstream ensures eventual consistency.

- **Negative**:
  - Transient failures (e.g., DynamoDB throttling) are not automatically retried.
  - Requires monitoring and alerting to detect persistent failures.
  - If the upstream system stops sending messages, the device may remain enabled longer than expected.

## Alternatives Considered
- **Throw errors and retry**: This approach adds retry logic but increases load and complexity. Rejected because the natural retry mechanism from the push system is sufficient.
- **Use Dead Letter Queue (DLQ)**: This could capture persistent failures for manual review. Considered for future implementation if monitoring reveals issues.

## Related ADRs
- ADR 004: AWS SDK Bundling Strategy (related to Lambda performance)

## Date
2025-10-08
