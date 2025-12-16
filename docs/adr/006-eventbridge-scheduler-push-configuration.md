# ADR 006: EventBridge Scheduler Configuration for Push Messages

## Status
Accepted

## Context

The push messaging system uses AWS EventBridge Scheduler to schedule delayed push notifications. When a notification needs to be delivered at a specific time in the future, a one-time schedule is created in EventBridge Scheduler that triggers the push-scheduler Lambda function at the designated time.

EventBridge Scheduler has service quotas that impose limits on how quickly we can create schedules and how many schedules we can maintain. These quotas directly impact the throughput and concurrency settings we can use in our Lambda function that processes push messages from SQS.

Key AWS service quotas for EventBridge Scheduler:
- **CreateSchedule API rate limit**: 1,000 requests per second per region
- **Maximum schedules**: 10,000,000 schedules per region

The push-scheduler Lambda is triggered by an SQS queue and must balance processing efficiency with respecting these EventBridge Scheduler limits to avoid throttling.

## Decision

We have configured the following values for the push message processing system:

### SQS Queue Configuration
- **VisibilityTimeout**: 15 seconds

### Lambda Event Source Mapping
- **BatchSize**: 25 messages
- **MaximumBatchingWindowInSeconds**: 5 seconds
- **MaximumConcurrency**: 10 concurrent executions
- **Function Timeout**: 10 seconds

### Calculated Throughput Limits
With these settings, the maximum theoretical rate at which schedules can be created is:
- **Maximum requests per second**: BatchSize × MaximumConcurrency = 25 × 10 = **250 schedules/second**

This is well below the EventBridge Scheduler CreateSchedule API limit of 1,000 requests per second, providing a safety margin of 75%.

## Consequences

### Positive
- **Throttling Protection**: Operating at 25% of the CreateSchedule quota provides substantial headroom to prevent API throttling, even during traffic spikes
- **Shared Service Consideration**: The safety margin accounts for other services in the AWS account that may also use EventBridge Scheduler
- **Scalability Headroom**: If needed, MaximumConcurrency can be increased up to 4x (to 40) before approaching the API limit, assuming no other services are creating schedules
- **Efficient Batch Processing**: Processing 25 messages per invocation reduces Lambda invocation costs while maintaining reasonable latency
- **Resource Optimization**: MaximumConcurrency of 10 balances throughput with Lambda concurrent execution limits and costs

### Negative
- **Throughput Constraint**: The system is limited to creating 250 schedules per second maximum, which may become a bottleneck during extreme traffic peaks
- **Queue Backlog Risk**: If push notification demand consistently exceeds 250 messages/second, the SQS queue will grow, increasing overall delivery latency
- **Conservative Approach**: The 75% safety margin may be overly cautious if EventBridge Scheduler is not heavily used by other services in the account

### Trade-offs
- **Concurrency vs. API Limits**: Increasing MaximumConcurrency improves throughput but brings us closer to EventBridge Scheduler throttling limits
- **Batch Size vs. Latency**: Larger batches improve efficiency but increase processing time per invocation and the visibility timeout window
- **Safety Margin vs. Performance**: The conservative approach prioritizes reliability over maximum throughput

## Alternatives Considered

### Higher MaximumConcurrency (e.g., 20 or 40)
This would increase throughput to 500-1,000 schedules/second but would risk throttling, especially if other services are using EventBridge Scheduler. We prioritized system stability over maximum throughput.

### Lower BatchSize (e.g., 10)
This would reduce the per-invocation processing time and visibility timeout requirements but would increase Lambda invocation costs and reduce overall efficiency without addressing the EventBridge Scheduler limits.

## Related ADRs
None

## Date
November 2025
