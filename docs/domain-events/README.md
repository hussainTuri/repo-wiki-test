---
title: SNS Event Payload Format for Domain Events
---

# SNS Event Payload Format for Domain Events

This document describes the format of the messages published to the SNS topic by the `devices-stream` and `notifications-stream` Lambda functions. Consumers of this SNS topic should use this as a reference for integration.

## Overview

- One consolidated SNS topic for all messaging domain events (Device and Notification).
- S3-based event publishing is deprecated and should be disabled as soon as DS start using domain events.

Both Lambdas publish events to the SNS topic in the following JSON format:

```json
{
  "version": "domain-events-v1",
  "eventDetails": "{/* object, see below */}",
  "eventType": "Device | Notification"
}
```

- `version`:
  - Fixed string identifying the envelope version. Current value: `domain-events-v1`.
- `eventType`:
  - `Device`: Event about device lifecycle (from `devices-stream`)
  - `Notification`: Event about notification lifecycle (from `notifications-stream`)
- `eventDetails`:
  - Action-specific details for the event. It contains a minimal subset of fields relevant to the action.
  - For the latest TypeScript types, see the shared `@messaging/schema` package.

---

## Device Events (`eventType: "Device"`)

Produced by: `devices-stream` Lambda

### Actions
- `Created`: Device registered for the first time
- `Updated`: `loggedIn` or `channels` changed
- `Deleted`: Device record deleted

### Example Payload (Created)
```json
{
  "version": "domain-events-v1",
  "eventType": "Device",
  "eventDetails": {
    "action": "Created",
    "eventId": "c82fc6af-84ef-4121-9c1c-93c24c644cfa",
    "timestamp": 1710000000000,
    "userId": "user-1",
    "profileId": "profile-1",
    "deviceToken": "<token>",
    "pushService": "APNS",
    "channels": ["authorized", "some-channel"],
    "loggedIn": true
  }
}
```

### Example Payload (Updated)
```json
{
  "version": "domain-events-v1",
  "eventType": "Device",
  "eventDetails": {
    "action": "Updated",
    "eventId": "c82fc6af-84ef-4121-9c1c-93c24c644cfa",
    "timestamp": 1710000000000,
    "userId": "user-1",
    "profileId": "profile-1",
    "deviceToken": "<token>",
    "pushService": "APNS",
    "channels": [],
    "loggedIn": true,
    "isDisabled": false
  }
}
```

### Example Payload (Deleted)
```json
{
  "version": "domain-events-v1",
  "eventType": "Device",
  "eventDetails": {
    "action": "Deleted",
    "eventId": "c82fc6af-84ef-4121-9c1c-93c24c644cfa",
    "timestamp": 1710000000000,
    "userId": "user-1",
    "profileId": "profile-1",
    "deviceToken": "<token>",
    "pushService": "APNS"
  }
}
```

#### Device eventDetails shape

All device events include:
- `action`: `Created` | `Updated` | `Deleted`
- `eventId`: string (UUID)
- `timestamp`: number (epoch ms)
- `userId`: string
- `profileId`: string
- `deviceToken`: string
- `pushService`: `APNS` | `GCM`

Additional fields for `Created` and `Updated` actions:
- `channels`: string[]
- `loggedIn`: boolean
- `isDisabled`: boolean (only in `Updated` action)

---

## Notification Events (`eventType: "Notification"`)

Produced by: `notifications-stream` Lambda

### Actions
- `Created`: Notification created
- `Read`: Notification marked as read
- `Pushed`: Notification delivered to device
- `Deleted`: Notification deleted

Notes:
- `notificationId` maps to the DynamoDB image `id` (row_id) of the notification.
- Each action has a distinct `eventDetails` shape (minimal fields only).

### eventDetails by action

#### Created
```json
{
  "version": "domain-events-v1",
  "eventType": "Notification",
  "eventDetails": {
    "action": "Created",
    "eventId": "c82fc6af-84ef-4121-9c1c-93c24c644cfa",
    "timestamp": 1710000000000,
    "userId": "user-1",
    "profileId": "profile-1",
    "notificationId": "row-abc",
    "messageId": "msg-123"
  }
}
```

#### Read
```json
{
  "version": "domain-events-v1",
  "eventType": "Notification",
  "eventDetails": {
    "action": "Read",
    "eventId": "c82fc6af-84ef-4121-9c1c-93c24c644cfa",
    "timestamp": 1710000000000,
    "userId": "user-1",
    "profileId": "profile-1",
    "notificationId": "row-abc",
    "messageId": "msg-123",
    "device": "ios",
    "ctaId": "0",
    "typeOfInteraction": "viewed"
  }
}
```

#### Pushed
```json
{
  "version": "domain-events-v1",
  "eventType": "Notification",
  "eventDetails": {
    "action": "Pushed",
    "eventId": "c82fc6af-84ef-4121-9c1c-93c24c644cfa",
    "timestamp": 1710000000000,
    "userId": "user-1",
    "profileId": "profile-1",
    "notificationId": "row-abc",
    "messageId": "msg-123"
  }
}
```

#### Deleted
```json
{
  "version": "domain-events-v1",
  "eventType": "Notification",
  "eventDetails": {
    "action": "Deleted",
    "eventId": "c82fc6af-84ef-4121-9c1c-93c24c644cfa",
    "timestamp": 1710000000000,
    "userId": "user-1",
    "profileId": "profile-1",
    "notificationId": "row-abc",
    "messageId": "msg-123"
  }
}
```

---

## Notes for Consumers
- The `eventDetails` object is intentionally minimal and action-specific
- New fields may be added over time
- All events are published as a single message per record.
- For the latest schema and TypeScript types, see `@messaging/schema`.