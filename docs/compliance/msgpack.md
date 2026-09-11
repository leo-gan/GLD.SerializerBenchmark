# MessagePack

MessagePack is an industry spec, not an RFC. The living document is
[spec.md](https://github.com/msgpack/msgpack/blob/master/spec.md).
Revisions are additive.

## Versions

| Label in this corpus | What landed | Parser-visible difference |
|----------------------|-------------|---------------------------|
| `2008-raw` | Original type chart | One **raw** family for text and bytes (`fixraw` / `raw 16` / `raw 32`). |
| `2013-str-bin` | August 2013 | **str** vs **bin**, plus **ext**. This is what current libraries speak. |
| `2017-timestamp` | August 2017 | Extension type **−1** (`0xff`): timestamp 32 / 64 / 96. |

There is no official “MessagePack 2.0” number (see
[msgpack/msgpack#195](https://github.com/msgpack/msgpack/issues/195)).

## What the cases cover

- fixint, nil, bool, fixarray, fixmap, uint/int, float64
- Legacy fixraw / modern fixstr (`a161` → `"a"`)
- bin 8 (`c4…`) as **bytes**, not text
- fixext 1 and timestamp 32 / 64 (accept-only: the host type varies)
- Rejects: truncated heads, reserved `0xc1`, short timestamp payload

Catalog: `compliance/data/msgpack/`. Inputs are hex.

## Python adapters

`msgpack` (`use_bin_type=True` on encode) and `msgspec.msgpack`.

Both current libraries understand 2013+ types, so they pass the 2008
raw cases that overlap the str family. A decoder that still treated
raw as opaque bytes only would fail the `decoded: "a"` cases.

## Official suite we did not vendor

[kawanet/msgpack-test-suite](https://github.com/kawanet/msgpack-test-suite)
is MIT. We recreated hex vectors from the published type chart with
original grouping. See [legal provenance](legal.md).
