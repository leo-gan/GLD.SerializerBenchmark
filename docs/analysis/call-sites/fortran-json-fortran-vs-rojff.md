# Fortran: `json-fortran` vs. `rojff`

This note inspects two pure-Fortran JSON libraries—`json-fortran` and `rojff`—on the `document` ($n = 1$, `bytes` mode) payload. Because Fortran lacks compiler or runtime reflection, both adapters explicitly construct an in-memory JSON value tree and emit identical compact UTF-8 text.

[Dashboard comparison (L1)](../../dashboard/index.html?lang=fortran&standard=json&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=json-fortran&ser=json-fortran&ser=rojff#compare) · [Fortran overview](../../fortran/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `json-fortran` | `rojff` |
|---|---|---|
| Standard | `json` (compact) | `json` (compact) |
| Encoded size (`document`, $n = 1$) | **473 B** | **473 B** (identical) |
| DOM representation | Mutable `json_value` tree via `json_core` | Immutable `json_object_t` built via `json_object_unsafe` |
| Integer kind (`json_IK`) | `int64` (built with `-DINT64 -DREAL64`) | Default `int32`; values outside 32-bit emit as JSON numbers (`float64`, exact $< 2^{53}$) |
| Post-decode fidelity | Checked field-by-field outside the timer | Checked field-by-field outside the timer |

## Timed Call Sites

**`json-fortran`** (`fortran/src/ser_json_fortran.f90`) constructs the `json_value` tree through `json_core` and serializes with whitespace disabled and strict type checks enabled:

```fortran
call core%initialize(no_whitespace=.true., strict_type_checking=.true.)
call write_record(core, root, items(1), stat)
call core%serialize(root, text)
```

Decode invokes `core%deserialize` followed by typed `core%get` calls.

**`rojff`** (`fortran/src/ser_rojff.f90`) builds a `json_object_t` via `json_object_unsafe` and `json_member_unsafe` (the type's default constructor is deleted) and prints/parses compact JSON:

```fortran
root = record_object(items(1), stat)
text = root%to_compact_string()
! decode:
parsed = parse_json_from_string(text)
```

## Mechanistic Analysis and Scope Limits

1. **Identical wire payload (473 B):** On `document`, all integer values (`status`, `version`, `qty`, `price_minor`) fit within signed 32-bit integers, so both libraries serialize identical compact JSON. Any latency difference reflects DOM node allocation, string concatenation, and parser implementation inside each pure-Fortran library.
2. **64-bit integer divergence on `telemetry` and `event`:** Epoch-millisecond timestamps ($\approx 1.7 \times 10^{12}$) exceed signed 32-bit range. Because `json-fortran` is compiled with `-DINT64`, it encodes timestamps as JSON integers; `rojff` formats them as JSON numbers (`json_number_t`) and recovers them via `nint` (exact up to $2^{53}$).
3. **Pure-Fortran boundary:** Neither adapter calls a C JSON library. The cost of calling a C codec across Fortran's `iso_c_binding` boundary is measured separately in [Experiment 4: Fortran FFI tax](../../experiments/index.md).
