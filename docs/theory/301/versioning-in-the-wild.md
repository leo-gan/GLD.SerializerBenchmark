# Versioning strategies in the wild

## Problem

Schemas and APIs change while old clients and old data remain. Pure theory (“never break anything”) collides with product deadlines. Without a playbook, teams mix silent renames, hard cutovers, and dual stacks until no one knows which version is canonical.

This page is that playbook. In other words, it answers: when a change cannot be purely additive, how do you ship it without stranding clients or corrupting data?

---

## Short answer

Prefer **additive, backward-compatible** changes first. An **additive** change introduces new optional information without removing or redefining existing fields. When a break is unavoidable, use an explicit **versioning surface**—URL, header, content type, topic name, or schema subject version—plus a **migration window**. During that window you dual-read and/or dual-write, watch metrics on old-path usage, and only then remove the old path.

- **Dual-write** means writers emit both the old and the new shape until all readers understand the new one.
- **Dual-read** means readers understand both shapes until writers stop sending the old one.
- **Kill criteria** are measurable rules that say when the old path may be deleted (for example, “old version under 1% of traffic for seven days”).

Align the tactic with schema culture ([two schema cultures](two-schema-cultures.md), [registries](schema-registries.md)) and with public versus internal boundaries ([public API contracts](public-api-contracts.md)).

This page assumes 201 [schema evolution](../201/schema-evolution.md).

---

## Constraints that matter

| Tactic | Best when | Cost |
|--------|-----------|------|
| **Additive optional fields** | Default path for almost every change | Low if defaults exist for old readers |
| **Dual-write** | Old and new consumers must run during a transition | Extra storage and CPU; you need consistency rules |
| **Dual-read** | New code must understand both shapes | Complexity concentrated in one service |
| **Content-type or Accept headers** | Multiple encodings or versions on one URL | Requires client discipline |
| **URL or topic version** | Hard breaks that need clear isolation | Proliferation of endpoints or topics |
| **Expand/contract** | Database-style migrations applied to messages | Multi-step discipline over several deploys |

**Expand/contract** means you first expand the system to support both old and new forms, migrate traffic, then contract by removing the old form. It is a multi-deploy discipline, not a single release.

---

## Decision frame

```text
  Can the change be additive with defaults?
    yes → do that; document it; test old writers × new readers and the reverse
    no  → pick a version surface + dual period + kill criteria
```

| Break type | Example playbook |
|------------|------------------|
| Rename a field | Dual-write both names; readers prefer the new name; then drop the old one |
| Change a type | Introduce a new field number or name; migrate; never overload the old identity |
| Change semantics | Ship a new version; do not silently reuse the old field |
| Remove a field | Ensure no readers remain; use a registry or CI gate; then remove |

This matters because “we’ll just rename it; JSON is flexible” is how silent client breakage ships under a calm commit message.

---

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Big-bang cutover | Partial deploy causes outage |
| Dual-write forever | Permanent complexity with no end date |
| No usage metrics | You never know when it is safe to remove the old path |
| Version only in documentation | Clients ignore it |
| Reuse of Protobuf field numbers | Silent corruption |

For example, dual-write without kill criteria becomes a permanent second schema that every engineer must remember forever.

---

## Real-world sketch

An orders API must change `amount` from floating point to integer cents. The team adds `amount_cents`, dual-writes both fields, and teaches readers to prefer `amount_cents` when present. Dashboards track old-field usage. After 90 days they deprecate `amount`. A parallel event subject uses registry FULL compatibility so accidental removal fails continuous integration.

---

## In this suite

| Resource | Role |
|----------|------|
| **Results** | Cost of encoding two shapes during dual-write, if you model that scenario |
| Fixtures | Stable logical models—not multi-version simulators |
| Capstones | Decision context for REST, events, and RPC |

---

## Experiments

**Question:** For a breaking wire change, which **versioning strategy** (dual-write, content-type, parallel subject, feature flag) meets kill criteria with acceptable cost?

### Setup

1. Define the break and the set of producers and consumers.
2. Pick one or two candidate strategies from the options above.
3. Ensure a metrics backend for error rate, lag, and traffic percentage on old versus new.

### Procedure

1. Implement the strategy in a non-production environment with both versions live.
2. Migrate a canary percentage of traffic; watch errors and lag.
3. Exercise rollback: force the old path and confirm recovery.
4. Write kill criteria (for example “old version under 1% of traffic for seven days”).
5. Only then schedule removal of the old path.

### Decision rule

- A strategy wins if the canary meets service-level objectives **and** rollback works within your incident budget.
- If you have no kill criteria, do not start dual-running.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Percentage of traffic on old versus new version** | **Primary** migration progress |
| Error rate by version | Safety |
| Consumer lag and dead-letter queue (DLQ) rate | Event-path health |
| Dual-run cost (CPU, storage) | Economic limit |
| Time to rollback | Operational risk |
| Kill-criteria boolean | Go or no-go for decommission |
| Suite benchmarks | Not primary for versioning operations |

**Conclusion style:** “Dual-write for two weeks; kill the old path when traffic is under 1% and the DLQ shows no spike.”

---

## What this suite cannot tell you

- How long *your* clients need before they upgrade.
- The political cost of a forced upgrade.
- The exact feature-flag design for your platform.

---

## Common mistakes

- Calling a break “minor” because JSON is flexible.
- Shipping dual-write without idempotent merge rules. **Idempotent** means applying the same update twice has the same effect as applying it once—important when dual systems can race.
- Dropping version 1 while mobile app binaries still call it.

---

## Key takeaways

- Prefer additive changes first; use a versioned break second; let metrics close the loop.
- Dual periods need **kill criteria**, not hope.
- Registry/CI gates and public OpenAPI are how strategy becomes enforceable.
- The suite does not simulate your client estate—instrument production.
