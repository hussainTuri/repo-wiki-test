---
title: Messaging System Documentation
---

# Messaging System Documentation

This folder contains architecture decision records (ADRs), operational runbooks, and reference docs for the messaging system.

## Navigation

- **Architecture Decision Records (ADRs)**
  - See the ADR index in [docs/adr](adr/).
  - Examples:
    - [ADR 001: TTL Value Strategy](adr/001-ttl-value-strategy.md)
    - [ADR 004: AWS SDK Bundling (Keep Everything Explicit)](adr/004-aws-sdk-bundling-strategy.md)

- **Dead Letter Queues (DLQ)**
  - [Push Dead Letter Queue (DLQ) – Operations & Reprocessing Guide](dlq/push.md)

- **Domain Events**
  - [SNS Event Payload Format for Domain Events](domain-events/events-structure.md)

- **Lambda Tuning**
  - [Lambda Performance Tuning (aws-lambda-power-tuning)](lambda/lambda-tuning.md)

## How to Use

- Start here to understand what kinds of docs exist.
- Drill into ADRs for context and rationale behind technical decisions.
- Use the DLQ guide and Lambda tuning docs as operational runbooks.
