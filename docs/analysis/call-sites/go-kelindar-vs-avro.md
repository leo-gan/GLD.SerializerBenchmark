# Go: `kelindar/binary` vs. `hamba/avro`

This note inspects the Go `kelindar/binary` and `hamba/avro` adapters on the `document` ($n = 1$, `bytes` mode) payload. Both omit field names, encode integers with zigzag variable-length encoding, and cache reflection-derived field encoders at runtime (neither uses source-code generation).

[Dashboard comparison (L1)](../../dashboard/index.html?lang=go&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=kelindar/binary&ser=kelindar/binary&ser=hamba/avro#compare) · [Go overview](../../go/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `kelindar/binary` | `hamba/avro` |
|---|---|---|
| Standard | `custom` (Go-only binary) | `avro` (Apache Avro binary datum) |
| Encoded size (`document`, $n = 1$) | **113 B** | **116 B** (+3 B) |
| Wire framing | Positional struct order; zigzag varints; `uvarint` lengths | Positional schema order; Avro zigzag varints; array block framing |
| Dispatch mechanism | Cached `reflect` codec slice (`sync.Map`) | Cached `reflect2` unsafe field encoders keyed by `(schema.Fingerprint(), rtype)` |
| Output allocation | Reused `bytes.Buffer` + copy to fresh `[]byte` | Pooled writer (`api.Marshal`) + copy to fresh `[]byte` |
| Cross-language & evolution | Go-only; no schema evolution | Cross-language Avro spec with writer/reader schema resolution |

## Timed Call Sites

**`kelindar/binary`** (`go/serializers/kelindar_binary.go`) resets a reused `Encoder` and `bytes.Buffer`, encodes `fx.Value`, and copies out a returned slice:

```go
func (s *kelindarBinary) SerializeBytes(fx model.Fixture) ([]byte, error) {
	s.buf.Reset()
	s.enc.Reset(&s.buf)
	if err := s.enc.Encode(fx.Value); err != nil {
		return nil, err
	}
	out := make([]byte, s.buf.Len())
	copy(out, s.buf.Bytes())
	return out, nil
}
```

**`hamba/avro`** (`go/serializers/avro.go`) parses the Avro schema once during untimed setup, then marshals using the frozen API (which borrows a pooled writer internally):

```go
func (s *hambaAvro) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return s.api.Marshal(s.schema, fx.Value)
}
```

## Mechanistic Analysis and Scope Limits

1. **Why wire sizes differ by only 3 bytes (113 B vs. 116 B):** Both formats omit field names and field tags entirely and use zigzag varints for signed integers. The 3-byte delta stems from Avro's array-block framing (count followed by a trailing `0` terminator) and minor integer encoding differences rather than metadata overhead.
2. **Why throughput is closely matched:** Both adapters avoid per-call reflection scanning by caching compiled field plans (`kelindar`'s `reflectStructCodec` slice vs. `hamba`'s `reflect2` pointer-offset encoders) and both perform one final `[]byte` copy. Because `hamba/avro` uses `reflect2` unsafe pointers while `kelindar/binary` traverses `reflect.Value` fields, minor Go toolchain or library updates can narrow or reverse the latency difference—check the live Dashboard CI overlap before declaring a winner.
3. **Interchange trade-off:** `kelindar/binary` is tied to Go struct field order with no versioning mechanism, whereas `hamba/avro` achieves comparable compactness and throughput while preserving cross-language Apache Avro interoperability and schema-registry evolution ([2.5 Schema evolution](../../theory/201/schema-evolution.md), [3.3 Schema cultures & registries](../../theory/301/two-schema-cultures.md)).
