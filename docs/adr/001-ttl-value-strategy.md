# ADR 001: TTL Value Strategy

## Status
Accepted

## Context
Items in the DynamoDb table `MtgApiDev-<env>-Messaging-Notifications` require a TTL to control their lifecycle. The decision needed to be made about how to set this TTL in relation to the item's endTime.

## Decision
We will set the TTL value for each item to be the endTime plus 1 week. If other teams processing this information needs it after that, they can use the source data from S3 bucket.
Also, We will add it as an environment variable so that we can control this value.

## Consequences
- Items will automatically expire one week after their endTime.
- Systems processing these items must account for the extra week of availability.
