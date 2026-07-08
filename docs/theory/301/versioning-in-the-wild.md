# Versioning strategies in the wild

> After reading this page, one should be able to pick dual-write, content-type, and additive-change tactics that match real deploy constraints.

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
