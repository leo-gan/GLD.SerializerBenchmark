# Fortran: json-fortran vs rojff

## Why this article exists

Fortran's JSON rows do not use compiler reflection. Each adapter walks the suite value and calls the library. **json-fortran** builds a `json_value` tree through `json_core`. **rojff** builds a `json_object_t` with unsafe constructors and prints it with `to_compact_string`. Both write named JSON. Both are pure Fortran.

This page opens those two timed call sites on the suite **document** fixture (one shop order). Measured times belong on the Dashboard slice below. The call sites are the part you can read without a chart.

[Open this slice on the Dashboard](../../dashboard/?lang=fortran&standard=json&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=json-fortran&ser=json-fortran&ser=rojff#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Fortran overview](../../fortran/)

## The two timed call sites

**json-fortran** (`fortran/src/ser_json_fortran.f90`) times `json_core` serialize and deserialize. One record is the object itself. There is no extra copy of the text inside the clock beyond what `serialize` allocates.

```fortran
call core%initialize(no_whitespace=.true., strict_type_checking=.true.)
call write_record(core, root, items(1), stat)
call core%serialize(root, text)
```

Decode is `core%deserialize`, then `core%get` for each field. `strict_type_checking` is on so an integer get does not silently turn a JSON number into an int32.

**rojff** (`fortran/src/ser_rojff.f90`) times `to_compact_string` and `parse_json_from_string`. The object is built with `json_object_unsafe` and `json_member_unsafe`. The type's intrinsic constructor is a deleted stub that error-stops, so the adapter cannot call `json_object_t()`.

```fortran
root = record_object(items(1), stat)
text = root%to_compact_string()
```

```fortran
parsed = parse_json_from_string(text)
```

Both rows then check the suite value field by field. That check is outside the deserialize timer. gzip and zstd sizes are outside both timers.

## Integers wider than int32

json-fortran is built with `-DINT64` and `-DREAL64`, so `json_IK` is int64. Epoch milliseconds stay JSON integers. rojff's integer kind is the compiler default, int32. A document `price_minor` is at most 100000, so both rows write it as a JSON integer.

Telemetry `ts` and event `occurred_at` are about 1.7e12. json-fortran writes those as JSON integers. rojff writes them as JSON numbers and reads them back with `nint`. They are exact in float64 below 2^53.

json-fortran:

```fortran
if (json_IK == int64 .or. (value >= -2147483648_int64 .and. value <= 2147483647_int64)) then
  call core%add(node, key, int(value, json_IK))
else
  call core%add(node, key, real(value, json_RK))
end if
```

rojff splits the same value with `json_integer_t` and `json_number_t`. A digit string with no decimal point is parsed as an integer. Writing the timestamp as digits would be a parse error, not a big integer.

## One full run on this host

Run `2026-10-10-133855`, gfortran 11.4, 100 repetitions, document, one record, bytes. The Dashboard default drops the warmup and IQR outliers. Both rows wrote **473** bytes. Median total time was **75.2 µs** for json-fortran and **99.2 µs** for rojff. Same JSON shape, a small gap. One machine, one run. json-fortran was built with `-DINT64`. This host's HDF5 and NetCDF Fortran modules are the Ubuntu 22.04 modules, which gfortran 13 cannot read, so this run used gfortran 11.4. CI installs gfortran 13 with that image's matching HDF5 package.

## What to look at on the Dashboard

1. **Size on document, one record.** Both write the same field names. A large gap means a different JSON shape, not a faster parser.
2. **Encode time.** `json_core%serialize` versus `to_compact_string`.
3. **Decode time.** `deserialize` plus `get` versus `parse_json_from_string` plus `%get`.
4. **Telemetry, not this document slice,** if you want the integer-kind difference. json-fortran writes the timestamp as a JSON integer. rojff writes it as a JSON number. fortran-messagepack stores that same timestamp as a MessagePack integer.

These times are Fortran on this runner. They are not a ranking against C or Python.
