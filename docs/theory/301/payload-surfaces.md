# Secrets, PII, and payload surfaces

## Problem

Serialization choices affect **where meaning appears in cleartext**: HTTP bodies, queue messages, core dumps, APM traces, exception messages, and “temporary” debug flags. A secure transport (TLS) does not protect **logs that capture the body**, nor support engineers pasting payloads into tickets. Incidents often start as performance or schema work and end as privacy breaches.

## Short answer

Treat every serialize path as creating a **payload surface**. Classify fields (public, internal, secret, regulated PII). Keep secrets **out of** routinely logged encodings; prefer references/tokens over raw credentials in messages. Redact at log/trace boundaries; restrict who can decode binary production traffic. Format choice (JSON vs binary) changes **ease of inspection**, not the need for a data-handling policy.

## Constraints that matter

| Surface | Risk |
|---------|------|
| **Access/application logs** | Full JSON bodies with PII |
| **APM / error trackers** | Request capture, breadcrumbs |
| **Message bus retention** | Long-lived events with personal data |
| **Support exports** | “Send us a sample payload” |
| **Client-side storage** | Tokens in local caches |
| **Core dumps / crash reports** | In-memory objects including secrets |

## Decision frame

| Field class | Prefer |
|-------------|--------|
| Auth secrets, keys | Never in durable business events; short-lived tokens only if unavoidable |
| Regulated PII | Minimize; encrypt or tokenize; retention policy |
| Internal ids | OK in portable contracts with access control |
| Debug-only dumps | Explicit flag, sampling, redaction, short TTL |

```text
  Would I paste this payload into a public ticket?
    no → ensure logs/traces cannot either
```

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Log full request/response by default | Bulk PII in SIEM |
| Binary “is safer” myth | Still decoded in tools; false confidence |
| Redact only in one service | Downstream still logs |
| Schema fields named `password`, `ssn` in events | Permanent topic pollution |
| Sharing production MessagePack in Slack | Uncontrolled copies |

## Real-world sketch

A team switches internal RPC to Protobuf for speed. Debugging gets harder, so they enable “log decoded message on error.” Error rates spike during an outage; PII floods the log pipeline. The codec change did not cause the leak—the **error surface** did. A better design: structured error codes, correlation ids, and optional secure debug buckets with access control—not full payload echo.

## In this suite

| Resource | Role |
|----------|------|
| Fixtures | Synthetic data—not a privacy model |
| **Results** | Size/time only |
| [Using this suite](using-this-suite.md) | Measurement honesty, not compliance |


## Experiments

**Question:** Where can **secrets/PII** in serialized payloads leak (logs, traces, caches, support tools), and what redaction is required?

### Setup
1. Inventory serializers on the path (API bodies, queue payloads, cache values).  
2. List secondary systems: APM, structured logs, DLQ dumps, admin UIs.  
3. Mark fields: secret, PII, regulated, benign.

### Procedure
1. Trace one request: note every component that might log raw payload or fields.  
2. Check default log level and exception formatters for body capture.  
3. For each sink, require allowlist/redaction or payload omission.  
4. Confirm support tooling cannot pull production payloads without access control.  
5. Re-test after a deliberate fault (failed deser) to ensure error paths do not dump secrets.

### Decision rule
- Any sink with unrestricted payload logging ⇒ fix redaction or drop body logging before ship.  
- Serialization format choice is secondary to **surface control**.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Count of sinks that can see raw payload** | **Primary** exposure metric |
| **Fields classified secret/PII** | Scope of redaction |
| **Redaction coverage** (% sensitive fields scrubbed) | Control effectiveness |
| Access-control on DLQ/debug endpoints | Residual risk |
| Log volume of payload-sized events | Cost + leak amplification |
| Suite metrics | Not primary for this decision |

**Conclusion style:** “APM and error logs redacted; DLQ restricted; no full-body info logs.”

## What this suite cannot tell you

- Legal classification of your fields (GDPR, HIPAA, …).  
- Correct retention periods.  
- Whether your log vendor is in-region.

## Common mistakes

- Using production payloads as permanent test fixtures in git.  
- Assuming encryption at rest on the bus makes logging safe.  
- Forgetting secondary surfaces (metrics labels with user ids).

## Key takeaways

- Serialization creates **inspectable artifacts**; policy must cover them.  
- JSON vs binary changes friction, not obligation.  
- Redact and minimize at every payload surface—not only at the TLS hop.  
- The suite does not substitute for a data-handling review.
