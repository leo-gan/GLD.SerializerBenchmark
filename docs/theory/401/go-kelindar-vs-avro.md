# Go: why kelindar/binary edges hamba/avro on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **kelindar/binary** and **hamba/avro** finish within about **10 percent** of each other. Their messages are almost the same size (113 bytes versus 116). Both omit field names. Both cache a per-type encode plan. This pair is useful because the *idea* is the same and the remaining difference is visible in the walk each library performs.

This page compares the two timed wrappers and the library code they invoke.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=go&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=kelindar/binary&ser=kelindar/binary&ser=hamba/avro#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Go overview](../../go/)

## Short answer

Both libraries write **values in a fixed order** with variable-length integers. kelindar/binary walks a cached list of field codecs. hamba/avro walks a cached list of field encoders that is *keyed by an Avro schema* as well as by the Go type. The extra schema match, and Avro’s rules for defaults, are the small time gap. The extra Avro metadata that is *not* on the wire is why the sizes stay within three bytes.

| | kelindar/binary | hamba/avro |
|--|-----------------|------------|
| Mean encode + decode, document, *n* = 1 | **476 thousand / s** | 436 thousand / s |
| Encoded size | **113 B** | 116 B |
| Plan | Cached `reflect` codecs | Cached `reflect2` encoders + schema |
| Names on the wire | No | No |

Neither path generates Go source. “Code generation” in the 201 sense is not what these two packages do.

## The two timed call sites

**kelindar/binary** (`go/serializers/kelindar_binary.go`) reuses an `Encoder` and a `bytes.Buffer`. Timed encode resets both, writes `fx.Value`, then copies the bytes out:

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

**hamba/avro** (`go/serializers/avro.go`) parses the schema once (untimed cache) and then:

```go
func (s *hambaAvro) SerializeBytes(fx model.Fixture) ([]byte, error) {
	return s.api.Marshal(s.schema, fx.Value)
}
```

`Marshal` borrows a writer from a pool, encodes, and copies the result out (hamba `config.go`). Both wrappers therefore pay one copy into a fresh `[]byte`. That cost is shared.

## What kelindar walks

[kelindar/binary](https://github.com/kelindar/binary) (Roman Atachiants) scans a Go type once into a `sync.Map` of codecs (`scanner.go`). A struct codec is a slice of field index plus child codec. Encode is a loop:

```go
// codecs.go — reflectStructCodec.EncodeTo
func (c reflectStructCodec) EncodeTo(e *Encoder, rv reflect.Value) (err error) {
	for _, i := range c {
		if err = i.Codec.EncodeTo(e, rv.Field(i.Index)); err != nil {
			return
		}
	}
	return
}
```

There is no field name and no field number. Integers are zigzag variable-length integers. Strings are `uvarint(length)` plus bytes. The README states the format is Go-only and has no versioning story.

## What hamba walks

[hamba/avro](https://github.com/hamba/avro) implements [Apache Avro](https://avro.apache.org/) (Doug Cutting and colleagues, 2009). The data bytes of a record are the fields in **schema** order. The schema itself lives beside the file or in a registry, not in every message.

`Writer.WriteVal` looks up an encoder by **schema fingerprint and Go type**, compiling one on the first use:

```go
// codec.go
func (w *Writer) WriteVal(schema Schema, val any) {
	encoder := w.cfg.getEncoderFromCache(schema.Fingerprint(), reflect2.RTypeOf(val))
	if encoder == nil {
		encoder = w.cfg.EncoderOf(schema, reflect2.TypeOf(val))
	}
	encoder.Encode(reflect2.PtrOf(val), w)
}
```

A record encoder is a fixed slice of unsafe field accessors. Integers are Avro zigzag varints, the same family kelindar uses. That is why 113 and 116 bytes sit together: both layouts are “values only, compact integers.” The three extra bytes are Avro’s slightly different integer and array-block rules, not field names.

The extra *time* is the schema-shaped walk: fingerprint lookup, per-field Avro encoders, and the rules Avro needs so that a later reader can apply a *different* schema. kelindar has no such rules.

## Side-by-side

| Step | kelindar/binary | hamba/avro |
|------|-----------------|------------|
| First call | `scan(t)` into a codec list | `EncoderOf(schema, typ)` into a field list |
| Later calls | `EncodeTo` on that list | `Encode` on that list |
| Integer | Zigzag varint | Avro zigzag varint |
| Who knows the field order | The Go struct | The Avro schema (must match the struct) |
| Another language | No | Yes, if it has the schema |

## What you give up

kelindar/binary is the faster private dump. It is not a contract you can hand to Java or Python.

hamba/avro is three percent larger and about ten percent slower on this fixture, and it is a format with twenty years of data-platform use. If the document will sit in a log for years, Avro’s schema resolution is the reason to pay those nanoseconds. See [201 schema evolution](../201/schema-evolution.md) and [301 schema registries](../301/schema-registries.md).

## Self-check

1. Why does “both omit names” predict similar sizes but not identical times?
2. kelindar is sometimes described as “generated.” What does the source actually generate, and when?
3. Which library would you pick if a Python reader must consume the same bytes next year?
