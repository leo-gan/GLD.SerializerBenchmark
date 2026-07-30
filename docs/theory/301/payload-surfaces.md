# Secrets, PII, and payload surfaces

## Problem

Serialization choices affect **where meaning appears in cleartext**: HTTP bodies, queue messages, core dumps, application performance monitoring (APM) traces, exception messages, and “temporary” debug flags. In plain language, every time you turn an object into bytes, those bytes can be copied, stored, or read by systems you did not originally have in mind.

A secure transport such as **TLS** (Transport Layer Security—the encryption that powers HTTPS) protects data while it travels on the network. TLS does **not** protect **logs that capture the body**, and it does not stop support engineers from pasting payloads into tickets.

**PII** means *personally identifiable information*: data that can identify a person, such as a name, email address, or government identifier. **Secrets** are credentials and keys that must not leak (passwords, API tokens, private keys).

Incidents often start as performance or schema work and end as privacy breaches. This page teaches you to see serialization as a **surface problem**, not only as a speed problem.

---

## Short answer

Treat every serialize path as creating a **payload surface**—a place where serialized meaning can be inspected, copied, or retained. Classify fields into public, internal, secret, and regulated PII. Keep secrets **out of** routinely logged encodings. Prefer references or short-lived tokens over raw credentials in messages.

Redact at log and trace boundaries. Restrict who can decode binary production traffic. The choice between JSON and binary changes **ease of inspection**, not the need for a data-handling policy.

In other words, binary formats make casual reading harder; they do not create a privacy policy for you.

---

## Constraints that matter

| Surface | Risk |
|---------|------|
| **Access and application logs** | Full JSON bodies that contain PII |
| **APM and error trackers** | Request capture and breadcrumb storage |
| **Message bus retention** | Long-lived events that still carry personal data |
| **Support exports** | “Please send us a sample payload” workflows |
| **Client-side storage** | Tokens stored in local caches |
| **Core dumps and crash reports** | In-memory objects that include secrets |

This matters because a secure API hop can still leak through a log pipeline that stores full request bodies for thirty days.

---

## Decision frame

| Field class | Prefer |
|-------------|--------|
| Auth secrets and keys | Never put these in durable business events; use short-lived tokens only if unavoidable |
| Regulated PII | Minimize what you store; encrypt or tokenize; apply a retention policy |
| Internal identifiers | Acceptable in portable contracts when access control is in place |
| Debug-only dumps | Require an explicit flag, sampling, redaction, and a short time-to-live (TTL) |

**Tokenization** replaces a sensitive value with a meaningless stand-in that only a controlled system can reverse. **TTL** (time-to-live) is how long data is allowed to remain before automatic deletion.

A useful personal test:

```text
  Would I paste this payload into a public ticket?
    no → ensure logs and traces cannot paste it either
```

If you would not share the payload publicly, your observability stack must not share it either.

---

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Logging full request and response bodies by default | Bulk PII lands in the security information and event management (SIEM) system |
| Believing “binary is safer” | Bytes are still decoded in tools; the myth creates false confidence |
| Redacting in only one service | Downstream services still log the sensitive fields |
| Schema fields named `password` or `ssn` in long-lived events | Permanent pollution of the event topic |
| Sharing production MessagePack dumps in Slack | Uncontrolled copies outside access control |

For example, a SIEM is a central security log system. If full bodies land there by default, you have created a long-lived, highly privileged store of personal data.

---

## Real-world sketch

A team switches internal RPC to Protobuf for speed. Debugging gets harder, so they enable “log the decoded message on error.” Error rates spike during an outage, and PII floods the log pipeline. The codec change did not cause the leak—the **error surface** did.

A better design uses structured error codes, correlation identifiers, and optional secure debug buckets with access control—not full payload echo on every failure.

---

## In this suite

| Resource | Role |
|----------|------|
| Fixtures | Synthetic data—not a privacy model for your product |
| **Results** | Size and time only |
| [Using this suite](using-this-suite.md) | Measurement honesty, not compliance guidance |

---

## Experiments

**Question:** Where can **secrets and PII** in serialized payloads leak (logs, traces, caches, support tools), and what redaction is required?

### Setup

1. Inventory serializers on the path: API bodies, queue payloads, and cache values.
2. List secondary systems: APM, structured logs, dead-letter queue (DLQ) dumps, and admin user interfaces. A **dead-letter queue** holds messages that failed processing so operators can inspect them later.
3. Mark fields as secret, PII, regulated, or benign.

### Procedure

1. Trace one request and note every component that might log the raw payload or individual fields.
2. Check default log levels and exception formatters for body capture.
3. For each sink, require an allowlist, redaction, or complete omission of payloads.
4. Confirm support tooling cannot pull production payloads without access control.
5. Re-test after a deliberate fault (for example a failed deserialize) to ensure error paths do not dump secrets.

### Decision rule

- Any sink with unrestricted payload logging must be fixed—redact or drop body logging—before ship.
- Serialization format choice is secondary to **surface control**.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Count of sinks that can see the raw payload** | **Primary** exposure metric |
| **Fields classified as secret or PII** | Scope of redaction work |
| **Redaction coverage** (percentage of sensitive fields scrubbed) | Control effectiveness |
| Access control on DLQ and debug endpoints | Residual risk |
| Log volume of payload-sized events | Cost and leak amplification |
| Suite metrics | Not primary for this decision |

**Conclusion style:** “APM and error logs are redacted; the DLQ is restricted; we never emit full-body info logs.”

---

## What this suite cannot tell you

- The legal classification of your fields (GDPR, HIPAA, and similar regimes).
- Correct retention periods for your jurisdiction and product.
- Whether your log vendor stores data in the required region.

---

## Common mistakes

- Using production payloads as permanent test fixtures in git.
- Assuming encryption at rest on the bus makes logging safe.
- Forgetting secondary surfaces such as metrics labels that embed user identifiers.

---

## Key takeaways

- Serialization creates **inspectable artifacts**, and policy must cover them.
- JSON versus binary changes friction, not obligation.
- Redact and minimize at every payload surface—not only at the TLS hop.
- The suite does not substitute for a data-handling review.
