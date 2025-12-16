# ADR 002: Updating notifications

## Status
Accepted

## Context
The CRM team should be able to update eligible notifications to fix typos, change start and end times etc.

## Decision
We will allow updates of notifications based on the key { row_id, customer_id, profile_id }. The immutable fields will at least be the key and the createdAt timestamp. 
- Notifications are not eligible for update if the timestamp in the filename is older than the timestamp in the existing notification.
- IPM notifications are only eligible for update if they have not been read.
- Push notifications are only eligible for update if they are in the pending state, meaning they have not yet been selected for sending. 

## Consequences
No particular consequences other than what is obvious from the decision.

## Date
2025-08-07
