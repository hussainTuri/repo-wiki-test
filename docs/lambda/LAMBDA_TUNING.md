# Lambda Performance Tuning (aws-lambda-power-tuning)

This document captures how we tune the memory/CPU configuration of the messaging system lambdas using the open‑source Step Functions state machine: <https://github.com/alexcasalboni/aws-lambda-power-tuning>.

The tuning process helps us pick a memory size that balances execution time (latency) and cost. Increasing memory also proportionally increases CPU *and* network throughput for a Lambda invocation, so the *cheapest* configuration is not always the *lowest* memory; the optimal point is often where the cost curve flattens or the latency SLO is met with minimal extra cost.

## General Approach

1. Deploy (or import) the `aws-lambda-power-tuning` state machine in the target AWS account/region.
2. Choose an initial range of memory power values. We typically start with: `128, 256, 512, 1024, 2048, 3008` (max classic memory for most of our functions today). Add/remove values if historical data suggests a narrower band.
3. Decide the strategy:
   - `cost` (default): Minimizes estimated cost (our default unless latency SLO pressure exists).
   - `speed`: Minimizes average duration.
   - `balanced`: Uses a heuristic balance of cost vs. speed.
4. Provide a representative `payload` for the function (see sections below). Make it realistic and deterministic where possible so results are comparable over time.
5. Run with `num` invocations per power (we use **10** to smooth variance; raise to 20+ for highly jittery IO-bound code if needed) and `parallelInvocation=true` for faster experiments.
6. Inspect the visualization: look for diminishing returns inflection point (where increasing memory no longer meaningfully reduces duration or cost begins to rise again).
7. Update the Lambda memory configuration (in infra repo / script) and note the result + date here.

### Default Tuning Input Skeleton

```json
{
  "lambdaARN": "<lambda-arn>",
  "powerValues": [128, 256, 512, 1024, 2048, 3008],
  "num": 10,
  "payload": "{}",
  "parallelInvocation": true,
  "strategy": "cost"
}
```

> NOTE: If the function needs environment priming (e.g., warm caches, JIT, large dependency load), consider a *warm-up* run first or ignore the first result set.

### Result Recording Convention

For each Lambda below we store:

- Date tuned (UTC)
- Chosen memory (MB)
- Strategy used
- Power values tested
- Example payload (trimmed for brevity)
- Rationale (short)

If a function has not yet been tuned, we keep a placeholder with TODO so it is easy to see coverage gaps.

> Global Note: Unless explicitly noted otherwise, all functions below were evaluated with the same power values set: `[128, 256, 512, 1024, 2048, 3008]`.

---

## fetch-ipm

**Last tuned:** 2025-09-03 (UTC)  
**Strategy:** cost  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Chosen memory:** 512 MB  
**Rationale:** 512 MB provided a substantial latency drop vs 256 MB with negligible incremental cost per request; higher tiers showed diminishing returns.  

Example invocation payload used (API Gateway HTTP request):

```json
{
  "version": "2.0",
  "rawPath": "/notifications/v1/viaplay/sv-se/lg2024xdk/users/test-user-123/profiles/test-profile-123",
  "pathParameters": {
    "brandId": "viaplay",
    "locale": "sv-se",
    "deviceKey": "lg2024xdk",
    "userId": "test-user-123",
    "profileId": "test-profile-123"
  },
  "queryStringParameters": {
    "programPageUrl": "https://content.viaplay.se/{device}-{country}{path}"
  },
  "headers": {},
  "body": {},
  "isBase64Encoded": false,
  "requestContext": { "http": { "method": "GET" } },
  "routeKey": "",
  "rawQueryString": ""
}
```

Power Tuning Input example:

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:fetch-ipm",
  "powerValues": [128, 256, 512, 1024, 2048, 3008],
  "num": 10,
  "payload": "<above JSON escaped as a single line>",
  "parallelInvocation": true,
  "strategy": "cost"
}
```


---

## ingest

**Last tuned:** 2025-09-03 (UTC)  
**Chosen memory:** TODO  
**Strategy:** balanced (expected heavy parsing & DynamoDB writes)  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Rationale:** CSV parsing + batch DynamoDB operations can benefit from more CPU until 1024–2048; balanced chosen to value latency for ingestion pipelines.

Representative payload (S3 event stub trimmed):

```json
{
  "Records": [
    {
      "eventSource": "aws:s3",
      "s3": {"bucket": {"name": "example-bucket"}, "object": {"key": "ingest/sample.csv"}}
    }
  ]
}
```
 
Tuning input (example):

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:ingest",
  "powerValues": [256, 512, 1024, 2048],
  "num": 10,
  "payload": "{\"Records\":[{\"eventSource\":\"aws:s3\",\"s3\":{\"bucket\":{\"name\":\"example-bucket\"},\"object\":{\"key\":\"ingest/sample.csv\"}}}]}",
  "parallelInvocation": true,
  "strategy": "balanced"
}
```

---

## inject

**Last tuned:** 2025-09-03 (UTC)  
**Chosen memory:** TODO  
**Strategy:** cost  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Rationale:** Primarily HTTP request validation + S3 put; not CPU intensive.

Example HTTP payload:

```json
{
  "version": "2.0",
  "rawPath": "/inject/notifications",
  "requestContext": {"http": {"method": "POST"}},
  "body": {"message": "Sample notification"}
}
```
 
Tuning input (example):

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:inject",
  "powerValues": [128, 256, 512, 1024],
  "num": 10,
  "payload": "{\"version\":\"2.0\",\"rawPath\":\"/inject/notifications\",\"requestContext\":{\"http\":{\"method\":\"POST\"}},\"body\":{\"message\":\"Sample notification\"}}",
  "parallelInvocation": true,
  "strategy": "cost"
}
```

---

## push

**Last tuned:** 2025-09-03 (UTC)  
**Chosen memory:** TODO  
**Strategy:** balanced  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Rationale:** Network calls to external push providers benefit from higher throughput; evaluate up to 2048.

Representative SQS event (single record):

```json
{
  "Records": [
    {
      "messageId": "00000000-0000-0000-0000-000000000000",
      "body": "{\"notificationId\":\"abc123\",\"userId\":\"user-1\"}"
    }
  ]
}
```
 
Tuning input (example):

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:push",
  "powerValues": [256, 512, 1024, 1536, 2048],
  "num": 10,
  "payload": "{\"Records\":[{\"messageId\":\"00000000-0000-0000-0000-000000000000\",\"body\":\"{\\\"notificationId\\\":\\\"abc123\\\",\\\"userId\\\":\\\"user-1\\\"}\"}]}",
  "parallelInvocation": true,
  "strategy": "balanced"
}
```

---

## push-notifications

**Last tuned:** 2025-09-03 (UTC)  
**Chosen memory:** TODO  
**Strategy:** cost  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Rationale:** Similar processing to `push` but internal; evaluate until diminishing returns.

Sample payload (generic internal trigger):

```json
{}
```
 
Tuning input (example):

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:push-notifications",
  "powerValues": [256, 512, 1024, 1536],
  "num": 10,
  "payload": "{}",
  "parallelInvocation": true,
  "strategy": "cost"
}
```

---

## register-device

**Last tuned:** 2025-09-03 (UTC)  
**Chosen memory:** 1024 MB  
**Strategy:** cost  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Rationale:** Similar to `register-device`; reuses patterns; expect low CPU.

Payload (example APIGatewayProxyEventV2 register request):

```json
{
  "version": "2.0",
  "routeKey": "PUT /push-notifications/devices/v1/users/{userId}/profiles/{profileId}",
  "rawPath": "/push-notifications/devices/v1/users/USER_ID/profiles/USER_ID",
  "rawQueryString": "",
  "headers": {
    "x-vp-authorization": "VIAPLAY-AT ACCESS_TOKEN",
    "content-type": "application/json"
  },
  "requestContext": {
    "accountId": "123456789012",
    "apiId": "abc123",
    "stage": "$default",
    "requestId": "RQID-xyz",
    "time": "04/Sep/2025:10:11:12 +0000",
    "timeEpoch": 1756980672000,
    "http": {
      "method": "PUT",
      "path": "/push-notifications/devices/v1/users/USER_ID/profiles/USER_ID",
      "protocol": "HTTP/1.1",
      "sourceIp": "203.0.113.10",
      "userAgent": "curl/8.0.1"
    }
  },
  "pathParameters": {
    "userId": "USER_ID",
    "profileId": "USER_ID"
  },
  "isBase64Encoded": false,
  "body": "{\"deviceToken\":\"ABCD123456789ABCD123456789ABCD\",\"pushService\":\"APNS\",\"device\":1,\"loggedIn\":true,\"channels\":[\"fake-news\"]}"
}
```

Tuning input (example):

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:register-device",
  "powerValues": [128, 256, 512, 1024],
  "num": 10,
  "payload": "{\"version\":\"2.0\",\"routeKey\":\"PUT /push-notifications/devices/v1/users/{userId}/profiles/{profileId}\",\"rawPath\":\"/push-notifications/devices/v1/users/USER_ID/profiles/USER_ID\",\"rawQueryString\":\"\",\"headers\":{\"x-vp-authorization\":\"VIAPLAY-AT ACCESS_TOKEN\",\"content-type\":\"application/json\"},\"requestContext\":{\"http\":{\"method\":\"PUT\",\"path\":\"/push-notifications/devices/v1/users/USER_ID/profiles/USER_ID\"}},\"pathParameters\":{\"userId\":\"USER_ID\",\"profileId\":\"USER_ID\"},\"isBase64Encoded\":false,\"body\":\"{\\\"deviceToken\\\":\\\"ABCD123456789ABCD123456789ABCD\\\",\\\"pushService\\\":\\\"APNS\\\",\\\"device\\\":1,\\\"loggedIn\\\":true,\\\"channels\\\":[\\\"fake-news\\\"]}\"}",
  "parallelInvocation": true,
  "strategy": "cost"
}
```

---

## report-ipm

**Last tuned:** 2025-09-03 (UTC)  
**Chosen memory:** 1024 MB  
**Strategy:** cost  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Rationale:** Lightweight read-receipt updates.

Payload example:

```json
{
  "version": "2.0",
  "rawPath": "/message-report/viaplay/section/sv-se/ios/userIds/123/profiles/456/messages/789/action/0",
  "routeKey": "$default",
  "rawQueryString": "",
  "headers": {},
  "requestContext": { "http": { "method": "POST" } },
  "isBase64Encoded": false,
  "pathParameters": {},
  "queryStringParameters": {},
  "body": {}
}
```

Tuning input (example):

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:report-ipm",
  "powerValues": [128, 256, 512, 1024],
  "num": 10,
  "payload": "{\"version\":\"2.0\",\"rawPath\":\"/message-report/viaplay/section/sv-se/ios/userIds/123/profiles/456/messages/789/action/0\",\"routeKey\":\"$default\",\"rawQueryString\":\"\",\"headers\":{},\"requestContext\":{\"http\":{\"method\":\"POST\"}},\"isBase64Encoded\":false,\"pathParameters\":{},\"queryStringParameters\":{},\"body\":{}}",
  "parallelInvocation": true,
  "strategy": "cost"
}
```

---

## devices-stream (Kinesis / DynamoDB stream consumer?)

**Last tuned:** 2025-09-03 (UTC)  
**Chosen memory:** TODO  
**Strategy:** cost  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Rationale:** Stream processors often benefit from some CPU to deserialize & batch; start at 256.

Representative stream event (trimmed placeholder):

```json
{
  "Records": [ { "eventID": "1", "eventName": "INSERT" } ]
}
```

Tuning input (example):

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:devices-stream",
  "powerValues": [256, 512, 1024],
  "num": 10,
  "payload": "{\"Records\":[{\"eventID\":\"1\",\"eventName\":\"INSERT\"}]}",
  "parallelInvocation": true,
  "strategy": "cost"
}
```

---

## notifications-stream

**Last tuned:** 2025-09-03 (UTC)  
**Chosen memory:** 512 MB  
**Strategy:** cost  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Rationale:** 512 MB hit the cost/duration elbow: noticeable latency drop vs 256 MB; further gains from 1024 MB were marginal (< ~5% avg duration improvement) and increased estimated cost. Higher tiers showed no meaningful additional benefit for this IO/serialization mix.

Representative DynamoDB Streams event (covers create, read, pushed, delete transitions used in logic):

```json
{
  "Records": [
    {
      "eventID": "1",
      "eventName": "INSERT",
      "eventVersion": "1.1",
      "eventSource": "aws:dynamodb",
      "awsRegion": "eu-west-1",
      "dynamodb": {
        "ApproximateCreationDateTime": 1736131200,
        "Keys": { "id": { "S": "notif-created-001" } },
        "NewImage": {
          "id": { "S": "notif-created-001" },
          "messageId": { "S": "msg-1001" },
          "profileId": { "S": "profile-abc" },
          "userId": { "S": "user-123" },
          "createdAt": { "N": "1736131200123" },
          "updatedAt": { "N": "1736131200123" },
          "originalTimestamp": { "N": "1736131199000" },
          "pushStatus": { "S": "pending" }
        },
        "SequenceNumber": "111111",
        "SizeBytes": 256,
        "StreamViewType": "NEW_AND_OLD_IMAGES"
      },
      "eventSourceARN": "arn:aws:dynamodb:eu-west-1:123456789012:table/Notifications/stream/2025-01-05T12:00:00.000"
    },
    {
      "eventID": "2",
      "eventName": "MODIFY",
      "eventVersion": "1.1",
      "eventSource": "aws:dynamodb",
      "awsRegion": "eu-west-1",
      "dynamodb": {
        "ApproximateCreationDateTime": 1736131210,
        "Keys": { "id": { "S": "notif-read-002" } },
        "OldImage": {
          "id": { "S": "notif-read-002" },
          "messageId": { "S": "msg-1002" },
          "profileId": { "S": "profile-def" },
          "userId": { "S": "user-456" },
          "createdAt": { "N": "1736131100000" },
          "updatedAt": { "N": "1736131150000" },
          "pushStatus": { "S": "pending" }
        },
        "NewImage": {
          "id": { "S": "notif-read-002" },
          "messageId": { "S": "msg-1002" },
          "profileId": { "S": "profile-def" },
          "userId": { "S": "user-456" },
          "createdAt": { "N": "1736131100000" },
          "updatedAt": { "N": "1736131210000" },
          "pushStatus": { "S": "pending" },
          "readAt": { "N": "1736131210000" },
          "readAtDevice": { "S": "iphone-15-pro" },
          "readAtCtaId": { "S": "open-content" },
          "readAtTypeOfInteraction": { "S": "tap" }
        },
        "SequenceNumber": "222222",
        "SizeBytes": 512,
        "StreamViewType": "NEW_AND_OLD_IMAGES"
      },
      "eventSourceARN": "arn:aws:dynamodb:eu-west-1:123456789012:table/Notifications/stream/2025-01-05T12:00:00.000"
    },
    {
      "eventID": "3",
      "eventName": "MODIFY",
      "eventVersion": "1.1",
      "eventSource": "aws:dynamodb",
      "awsRegion": "eu-west-1",
      "dynamodb": {
        "ApproximateCreationDateTime": 1736131220,
        "Keys": { "id": { "S": "notif-pushed-003" } },
        "OldImage": {
          "id": { "S": "notif-pushed-003" },
          "messageId": { "S": "msg-1003" },
          "profileId": { "S": "profile-ghi" },
          "userId": { "S": "user-789" },
          "createdAt": { "N": "1736131000000" },
          "updatedAt": { "N": "1736131180000" },
          "pushStatus": { "S": "processing" }
        },
        "NewImage": {
          "id": { "S": "notif-pushed-003" },
          "messageId": { "S": "msg-1003" },
          "profileId": { "S": "profile-ghi" },
          "userId": { "S": "user-789" },
          "createdAt": { "N": "1736131000000" },
          "updatedAt": { "N": "1736131220000" },
          "pushStatus": { "S": "done" },
          "pushEvents": {
            "L": [
              {
                "M": {
                  "timestamp": { "N": "1736131220000" },
                  "provider": { "S": "apns" }
                }
              }
            ]
          }
        },
        "SequenceNumber": "333333",
        "SizeBytes": 640,
        "StreamViewType": "NEW_AND_OLD_IMAGES"
      },
      "eventSourceARN": "arn:aws:dynamodb:eu-west-1:123456789012:table/Notifications/stream/2025-01-05T12:00:00.000"
    },
    {
      "eventID": "4",
      "eventName": "REMOVE",
      "eventVersion": "1.1",
      "eventSource": "aws:dynamodb",
      "awsRegion": "eu-west-1",
      "dynamodb": {
        "ApproximateCreationDateTime": 1736131230,
        "Keys": { "id": { "S": "notif-deleted-004" } },
        "OldImage": {
          "id": { "S": "notif-deleted-004" },
          "messageId": { "S": "msg-1004" },
          "profileId": { "S": "profile-jkl" },
          "userId": { "S": "user-999" },
          "createdAt": { "N": "1736130500000" },
          "updatedAt": { "N": "1736130600000" }
        },
        "SequenceNumber": "444444",
        "SizeBytes": 220,
        "StreamViewType": "NEW_AND_OLD_IMAGES"
      },
      "eventSourceARN": "arn:aws:dynamodb:eu-west-1:123456789012:table/Notifications/stream/2025-01-05T12:00:00.000"
    }
  ]
}
```

Tuning input (example – payload escaped as single string):

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:notifications-stream",
  "powerValues": [256, 512, 1024],
  "num": 10,
  "payload": "{\"Records\":[{\"eventID\":\"1\",\"eventName\":\"INSERT\",\"eventVersion\":\"1.1\",\"eventSource\":\"aws:dynamodb\",\"awsRegion\":\"eu-west-1\",\"dynamodb\":{\"ApproximateCreationDateTime\":1736131200,\"Keys\":{\"id\":{\"S\":\"notif-created-001\"}},\"NewImage\":{\"id\":{\"S\":\"notif-created-001\"},\"messageId\":{\"S\":\"msg-1001\"},\"profileId\":{\"S\":\"profile-abc\"},\"userId\":{\"S\":\"user-123\"},\"createdAt\":{\"N\":\"1736131200123\"},\"updatedAt\":{\"N\":\"1736131200123\"},\"originalTimestamp\":{\"N\":\"1736131199000\"},\"pushStatus\":{\"S\":\"pending\"}},\"SequenceNumber\":\"111111\",\"SizeBytes\":256,\"StreamViewType\":\"NEW_AND_OLD_IMAGES\"},\"eventSourceARN\":\"arn:aws:dynamodb:eu-west-1:123456789012:table/Notifications/stream/2025-01-05T12:00:00.000\"},{\"eventID\":\"2\",\"eventName\":\"MODIFY\",\"eventVersion\":\"1.1\",\"eventSource\":\"aws:dynamodb\",\"awsRegion\":\"eu-west-1\",\"dynamodb\":{\"ApproximateCreationDateTime\":1736131210,\"Keys\":{\"id\":{\"S\":\"notif-read-002\"}},\"OldImage\":{\"id\":{\"S\":\"notif-read-002\"},\"messageId\":{\"S\":\"msg-1002\"},\"profileId\":{\"S\":\"profile-def\"},\"userId\":{\"S\":\"user-456\"},\"createdAt\":{\"N\":\"1736131100000\"},\"updatedAt\":{\"N\":\"1736131150000\"},\"pushStatus\":{\"S\":\"pending\"}},\"NewImage\":{\"id\":{\"S\":\"notif-read-002\"},\"messageId\":{\"S\":\"msg-1002\"},\"profileId\":{\"S\":\"profile-def\"},\"userId\":{\"S\":\"user-456\"},\"createdAt\":{\"N\":\"1736131100000\"},\"updatedAt\":{\"N\":\"1736131210000\"},\"pushStatus\":{\"S\":\"pending\"},\"readAt\":{\"N\":\"1736131210000\"},\"readAtDevice\":{\"S\":\"iphone-15-pro\"},\"readAtCtaId\":{\"S\":\"open-content\"},\"readAtTypeOfInteraction\":{\"S\":\"tap\"}},\"SequenceNumber\":\"222222\",\"SizeBytes\":512,\"StreamViewType\":\"NEW_AND_OLD_IMAGES\"},\"eventSourceARN\":\"arn:aws:dynamodb:eu-west-1:123456789012:table/Notifications/stream/2025-01-05T12:00:00.000\"},{\"eventID\":\"3\",\"eventName\":\"MODIFY\",\"eventVersion\":\"1.1\",\"eventSource\":\"aws:dynamodb\",\"awsRegion\":\"eu-west-1\",\"dynamodb\":{\"ApproximateCreationDateTime\":1736131220,\"Keys\":{\"id\":{\"S\":\"notif-pushed-003\"}},\"OldImage\":{\"id\":{\"S\":\"notif-pushed-003\"},\"messageId\":{\"S\":\"msg-1003\"},\"profileId\":{\"S\":\"profile-ghi\"},\"userId\":{\"S\":\"user-789\"},\"createdAt\":{\"N\":\"1736131000000\"},\"updatedAt\":{\"N\":\"1736131180000\"},\"pushStatus\":{\"S\":\"processing\"}},\"NewImage\":{\"id\":{\"S\":\"notif-pushed-003\"},\"messageId\":{\"S\":\"msg-1003\"},\"profileId\":{\"S\":\"profile-ghi\"},\"userId\":{\"S\":\"user-789\"},\"createdAt\":{\"N\":\"1736131000000\"},\"updatedAt\":{\"N\":\"1736131220000\"},\"pushStatus\":{\"S\":\"done\"},\"pushEvents\":{\"L\":[{\"M\":{\"timestamp\":{\"N\":\"1736131220000\"},\"provider\":{\"S\":\"apns\"}}}]}},\"SequenceNumber\":\"333333\",\"SizeBytes\":640,\"StreamViewType\":\"NEW_AND_OLD_IMAGES\"},\"eventSourceARN\":\"arn:aws:dynamodb:eu-west-1:123456789012:table/Notifications/stream/2025-01-05T12:00:00.000\"},{\"eventID\":\"4\",\"eventName\":\"REMOVE\",\"eventVersion\":\"1.1\",\"eventSource\":\"aws:dynamodb\",\"awsRegion\":\"eu-west-1\",\"dynamodb\":{\"ApproximateCreationDateTime\":1736131230,\"Keys\":{\"id\":{\"S\":\"notif-deleted-004\"}},\"OldImage\":{\"id\":{\"S\":\"notif-deleted-004\"},\"messageId\":{\"S\":\"msg-1004\"},\"profileId\":{\"S\":\"profile-jkl\"},\"userId\":{\"S\":\"user-999\"},\"createdAt\":{\"N\":\"1736130500000\"},\"updatedAt\":{\"N\":\"1736130600000\"}},\"SequenceNumber\":\"444444\",\"SizeBytes\":220,\"StreamViewType\":\"NEW_AND_OLD_IMAGES\"},\"eventSourceARN\":\"arn:aws:dynamodb:eu-west-1:123456789012:table/Notifications/stream/2025-01-05T12:00:00.000\"}]}",
  "parallelInvocation": true,
  "strategy": "cost"
}
```

---

## domain-events-logger

**Last tuned:** 2025-09-03 (UTC)  
**Chosen memory:** 1024 MB  
**Strategy:** cost  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Rationale:** Logging/forwarding tasks are low CPU; keep narrow range.
Example SNS notification payload used:

```json
{
  "Records": [
    {
      "EventSource": "aws:sns",
      "EventSubscriptionArn": "arn:aws:sns:eu-west-1:111122223333:example:sub-id",
      "Sns": {
        "Type": "Notification",
        "MessageId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "TopicArn": "arn:aws:sns:eu-west-1:111122223333:example",
        "Subject": "test",
        "Message": "{\"hello\":\"world\"}",
        "Timestamp": "2025-09-03T10:00:00.000Z",
        "SignatureVersion": "1",
        "Signature": "EXAMPLE==",
        "SigningCertUrl": "https://sns.eu-west-1.amazonaws.com/SimpleNotificationService-12345.pem",
        "UnsubscribeUrl": "https://sns.eu-west-1.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:eu-west-1:111122223333:example:sub-id",
        "MessageAttributes": {}
      }
    }
  ]
}
```

Tuning input (example):

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:domain-events-logger",
  "powerValues": [128, 256, 512],
  "num": 10,
  "payload": "{\"Records\":[{\"EventSource\":\"aws:sns\",\"EventVersion\":\"1.0\",\"EventSubscriptionArn\":\"arn:aws:sns:eu-west-1:111122223333:example:sub-id\",\"Sns\":{\"Type\":\"Notification\",\"MessageId\":\"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\",\"TopicArn\":\"arn:aws:sns:eu-west-1:111122223333:example\",\"Subject\":\"test\",\"Message\":\"{\\\"hello\\\":\\\"world\\\"}\",\"Timestamp\":\"2025-09-03T10:00:00.000Z\",\"SignatureVersion\":\"1\",\"Signature\":\"EXAMPLE==\",\"SigningCertUrl\":\"https://sns.eu-west-1.amazonaws.com/SimpleNotificationService-12345.pem\",\"UnsubscribeUrl\":\"https://sns.eu-west-1.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:eu-west-1:111122223333:example:sub-id\",\"MessageAttributes\":{}}}]} ",
  "parallelInvocation": true,
  "strategy": "cost"
}
```

---

## load-test

(Internal utility function – tune only if it materially affects load harness throughput.)

**Last tuned:** 2025-09-03 (UTC)  
**Chosen memory:** TODO / Not prioritized  
**Strategy:** speed (maximize throughput)  
**Power values tested:** 128, 256, 512, 1024, 2048, 3008  
**Rationale:** Synthetic load generation benefits from higher CPU; we bias toward speed for test efficiency.

Payload placeholder:

```json
{"action":"generate","count":100}
```

Tuning input (example):

```json
{
  "lambdaARN": "arn:aws:lambda:<region>:<account-id>:function:load-test",
  "powerValues": [512, 1024, 1536, 2048, 3008],
  "num": 10,
  "payload": "{\"action\":\"generate\",\"count\":100}",
  "parallelInvocation": true,
  "strategy": "speed"
}
```

---

## Updating This Document

When you complete a tuning run:

1. Replace `TODO` with the chosen memory size.
2. Adjust the date (UTC) and rationale if needed.
3. If the tested `powerValues` set changed, update it.
4. Commit alongside the infrastructure change that modifies the Lambda memory in the deployment pipeline.


## Future Improvements

- Automate retrieval & markdown generation via a script that queries the Step Functions execution output JSON and updates this file.
- Track historical runs (append a concise table per Lambda) for trend analysis.
- Include p95 / p99 latency deltas if we collect them separately.

---

Questions: reach out to the User Platform Team
