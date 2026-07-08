# Versioning strategies in the wild

## Problem

Schemas and APIs change while old clients and old data remain. Pure theory (“never break”) collides with product deadlines. Without a playbook, teams mix silent renames, hard cuts, and dual stacks until no one knows which version is canonical.

## Short answer

Prefer **additive, backward-compatible** changes first. When a break is unavoidable, use an explicit **versioning surface** (URL, header, content-type, topic name, schema subject version) plus a **migration window**: dual-read and/or dual-write, metrics on old-path usage, then remove. Align the tactic with schema culture ([two schema cultures](two-schema-cultures.md), [registries](schema-registries.md)) and with public vs internal boundaries ([public API contracts](public-api-contracts.md)).

Assumes 201 [schema evolution](../201/schema-evolution.md).

## Constraints that matter

| Tactic | Best when | Cost |
|--------|-----------|------|
| **Additive optional fields** | Default path | Low if defaults exist |
| **Dual-write** | Old and new consumers during transition | Storage/CPU; consistency rules |
| **Dual-read** | New code understands both shapes | Complexity in one service |
| **Content-type / Accept** | Multiple encodings or versions on one URL | Client discipline |
| **URL / topic version** | Hard breaks; clear isolation | Proliferation of endpoints |
| **Expand/contract** | DB-like migrations applied to messages | Multi-step discipline |

## Decision frame

```text
  Can change be additive with defaults?
    yes → do that; document; test old×new
    no  → pick version surface + dual period + kill criteria
```

| Break type | Example playbook |
|------------|------------------|
| Rename field | Dual-write both names; readers prefer new; then drop old |
| Type change | New field number/name; migrate; never overload old id |
| Semantic change | New version; do not silently reuse |
| Remove field | Ensure no readers; registry/CI gate; then remove |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Big-bang cutover | Partial deploy outage |
| Dual-write forever | Permanent complexity |
| No usage metrics | Never know when to remove old path |
| Version only in docs | Clients ignore it |
| Reuse Protobuf field numbers | Silent corruption |

## Real-world sketch

An orders API must change `amount` from float to integer cents. Team adds `amount_cents`, dual-writes, readers prefer `amount_cents` when present, dashboards track old field usage, then deprecate `amount` after 90 days. A parallel event subject uses registry FULL compatibility so accidental removal fails CI.

## In this suite

| Resource | Role |
|----------|------|
| **Results** | Cost of encoding two shapes during dual-write (if you model it) |
| Fixtures | Stable logical models—not multi-version simulators |
| Capstones | Decision context for REST / events / RPC |


## Experiments

**Question:** For a breaking wire change, which **versioning strategy** (dual-write, content-type, parallel subject, flag) meets kill criteria with acceptable cost?

### Setup
1. Define the break and the set of producers/consumers.  
2. Pick 1–2 candidate strategies from the article’s options.  
3. Metrics backend for error rate, lag, and traffic % on old vs new.

### Procedure
1. Implement strategy in a non-prod environment with both versions live.  
2. Migrate a canary % of traffic; watch errors and lag.  
3. Exercise rollback: force old path; confirm recovery.  
4. Write kill criteria (e.g. “old version <1% for 7 days”).  
5. Only then schedule old-path removal.

### Decision rule
- Strategy wins if canary meets SLOs **and** rollback works within your incident budget.  
- No kill criteria ⇒ do not start dual-running.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **% traffic on old vs new version** | **Primary** migration progress |
| Error rate by version | Safety |
| Consumer lag / DLQ rate | Event-path health |
| Dual-run cost (CPU, storage) | Economic limit |
| Time to rollback | Operational risk |
| Kill-criteria boolean | Go/no-go for decommission |
| Suite benchmarks | Not primary for versioning ops |

**Conclusion style:** “Dual-write 2 weeks; kill old when <1% and zero DLQ spike.”

## What this suite cannot tell you

- How long *your* clients need.  
- Political cost of a forced upgrade.  
- Exact feature-flag design.

## Common mistakes

- Calling a break “minor” because JSON is flexible.  
- Shipping dual-write without idempotent merge rules.  
- Dropping v1 while mobile app binaries still call it.

## Key takeaways

- Additive first; versioned break second; metrics close the loop.  
- Dual periods need **kill criteria**, not hope.  
- Registry/CI and public OpenAPI are how strategy becomes enforceable.  
- Suite does not simulate your client estate—instrument production.
