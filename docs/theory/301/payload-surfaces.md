# Secrets, PII, and payload surfaces

## Problem

Serialization choices affect **where meaning appears in cleartext**. Those places include HTTP bodies, queue messages, core dumps, and application performance monitoring (APM) traces. They also include exception messages and “temporary” debug flags. In plain language, every time you turn an object into bytes, those bytes can be copied. They can be stored. They can be read by systems you did not originally have in mind.

A secure transport such as **TLS** protects data while it travels on the network. **TLS** means Transport Layer Security. It is the encryption that powers HTTPS. TLS does **not** protect **logs that capture the body**. It also does not stop support engineers from pasting payloads into tickets.

**PII** means *personally identifiable information*. That is data that can identify a person. Examples include a name, an email address, or a government identifier. **Secrets** are credentials and keys that must not leak. Examples include passwords, API tokens, and private keys.

Incidents often start as performance or schema work. They end as privacy breaches. This page teaches you to see serialization as a **surface problem**. It is not only a speed problem.

---

## Short answer

Treat every serialize path as creating a **payload surface**. A payload surface is a place where serialized meaning can be inspected, copied, or retained. Classify fields into public, internal, secret, and regulated PII. Keep secrets **out of** routinely logged encodings. Prefer references or short-lived tokens over raw credentials in messages.

Redact at log and trace boundaries. Restrict who can decode binary production traffic. The choice between JSON and binary changes **ease of inspection**. It does not remove the need for a data-handling policy.

In other words, binary formats make casual reading harder. They do not create a privacy policy for you.

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

This matters because a secure API hop can still leak through a log pipeline. That pipeline may store full request bodies for thirty days.

---

## Decision frame

| Field class | Prefer |
|-------------|--------|
| Auth secrets and keys | Never put these in durable business events; use short-lived tokens only if unavoidable |
| Regulated PII | Minimize what you store; encrypt or tokenize; apply a retention policy |
| Internal identifiers | Acceptable in portable contracts when access control is in place |
| Debug-only dumps | Require an explicit flag, sampling, redaction, and a short time-to-live (TTL) |

**Tokenization** replaces a sensitive value with a meaningless stand-in. Only a controlled system can reverse that stand-in. **TTL** means time-to-live. It is how long data is allowed to remain before automatic deletion.

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

For example, a SIEM is a central security log system. If full bodies land there by default, you have created a long-lived store of personal data. That store is highly privileged.

---

## Real-world sketch

A team switches internal RPC to Protobuf for speed. Debugging gets harder. So they enable “log the decoded message on error.” Error rates spike during an outage. PII floods the log pipeline. The codec change did not cause the leak. The **error surface** did.

A better design uses structured error codes. It uses correlation identifiers. It uses optional secure debug buckets with access control. It does not echo full payloads on every failure.

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

1. Inventory serializers on the path. Include API bodies, queue payloads, and cache values.
2. List secondary systems. Include APM, structured logs, dead-letter queue (DLQ) dumps, and admin user interfaces. A **dead-letter queue** holds messages that failed processing. Operators can inspect them later.
3. Mark fields as secret, PII, regulated, or benign.

### Procedure

1. Trace one request. Note every component that might log the raw payload or individual fields.
2. Check default log levels and exception formatters for body capture.
3. For each sink, require an allowlist, redaction, or complete omission of payloads.
4. Confirm support tooling cannot pull production payloads without access control.
5. Re-test after a deliberate fault. One example is a failed deserialize. Ensure error paths do not dump secrets.

### Decision rule

- Any sink with unrestricted payload logging must be fixed. Redact or drop body logging before ship.
- Serialization format choice is secondary to **surface control**.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Count of sinks that can see the raw payload** | **Primary** exposure metric |
| **Fields classified as secret or PII** | Scope of redaction work |
| **Redaction coverage** (percentage of sensitive fields scrubbed) | Control effectiveness |
| Access control on DLQ and debug endpoints | Remaining risk |
| Log volume of payload-sized events | Cost and leak amplification |
| Suite metrics | Not primary for this decision |

**Conclusion style:** “APM and error logs are redacted; the DLQ is restricted; we never emit full-body info logs.”

---

## What this suite cannot tell you

- The legal classification of your fields. That includes GDPR, HIPAA, and similar regimes.
- Correct retention periods for your jurisdiction and product.
- Whether your log vendor stores data in the required region.

---

## Common mistakes

- Using production payloads as permanent test fixtures in git.
- Assuming encryption at rest on the bus makes logging safe.
- Forgetting secondary surfaces. One example is metrics labels that embed user identifiers.

---

## Key takeaways

- Serialization creates **inspectable artifacts**. Policy must cover them.
- JSON versus binary changes friction. It does not change obligation.
- Redact and minimize at every payload surface. Do not stop at the TLS hop alone.
- The suite does not substitute for a data-handling review.
