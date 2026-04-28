# Serializer Benchmark Summary

**Generated:** 2026-04-27T20:23:21.451440

---


## C# / .NET Benchmarks

| Serializer | Test Data | Mode | Avg Total (ns) | Ops/Sec | Size (bytes) |
|------------|-----------|------|----------------|---------|----------------|
| NetSerializer | Integer | Stream | 2,255 | 443,494 | 6 |
| Json.Net | Integer | string | 3,260 | 306,778 | 10 |
| Hyperion | Integer | Stream | 3,825 | 261,411 | 5 |
| Json.Net | Integer | Stream | 4,116 | 242,940 | 10 |
| ServiceStack Type | Integer | string | 4,230 | 236,428 | 10 |
| ServiceStack Type | Integer | Stream | 4,669 | 214,177 | 10 |
| GroBuf | Integer | Stream | 5,287 | 189,129 | 5 |
| NetJSON | Integer | Stream | 5,978 | 167,281 | 10 |
| NetSerializer | Integer | string | 6,152 | 162,544 | 8 |
| MS Bond Json | Integer | Stream | 6,312 | 158,424 | 2 |
| ServiceStack Json | Integer | string | 6,752 | 148,095 | 10 |
| Hyperion | Integer | string | 6,914 | 144,639 | 8 |
| ServiceStack Json | Integer | Stream | 7,162 | 139,632 | 10 |
| GroBuf | SimpleObject | Stream | 7,573 | 132,056 | 1 |
| NetSerializer | SimpleObject | Stream | 7,937 | 125,990 | 40 |
| Jil | Integer | Stream | 8,340 | 119,904 | 10 |
| MemoryPack | Integer | Stream | 8,975 | 111,424 | 5 |
| ProtoBuf | Integer | Stream | 10,725 | 93,241 | 6 |
| MS Bond Compact | Integer | Stream | 11,701 | 85,461 | 1 |
| Utf8Json | Integer | Stream | 12,494 | 80,037 | 10 |


## Python Benchmarks

| Serializer | Test Data | Mode | Avg Total (ns) | Ops/Sec | Size (bytes) |
|------------|-----------|------|----------------|---------|----------------|
| msgspec | Integer | bytes | 1,591 | 628,460 | 10 |
| orjson | Integer | bytes | 2,286 | 437,461 | 10 |
| msgpack | Integer | bytes | 2,861 | 349,501 | 5 |
| msgspec | Integer | stream | 2,906 | 344,169 | 10 |
| msgspec | SimpleObject | bytes | 3,091 | 323,504 | 102 |
| orjson | Integer | stream | 4,043 | 247,325 | 10 |
| msgspec | SimpleObject | stream | 4,383 | 228,175 | 102 |
| pickle | Integer | bytes | 4,423 | 226,084 | 17 |
| msgpack | Integer | stream | 4,697 | 212,901 | 5 |
| orjson | SimpleObject | bytes | 4,717 | 211,998 | 102 |
| rapidjson | Integer | bytes | 4,982 | 200,733 | 10 |
| orjson | SimpleObject | stream | 5,864 | 170,541 | 102 |
| rapidjson | Integer | stream | 6,123 | 163,311 | 10 |
| pickle | Integer | stream | 7,124 | 140,364 | 17 |
| cloudpickle | Integer | bytes | 10,079 | 99,213 | 17 |
| cloudpickle | Integer | stream | 13,473 | 74,223 | 17 |
| msgspec | Person | bytes | 15,678 | 63,785 | 908 |
| msgspec | Telemetry | bytes | 15,860 | 63,050 | 2,187 |
| orjson | Telemetry | stream | 16,220 | 61,652 | 2,187 |
| orjson | Telemetry | bytes | 16,604 | 60,225 | 2,187 |


## Top Performers by Language

### Fastest Serializers (by total time)

- **C#:** NetSerializer - 2,255 ns
- **Python:** msgspec - 1,591 ns

### Most Compact Output (by size)

- **C#:** MS Bond Compact - 1 bytes
- **Python:** msgpack - 5 bytes

## Multidimensional Analysis

### Best Performers by Data Type

- **EDI_835:** Python orjson (bytes) - 22,635 ns
- **Integer:** Python msgspec (bytes) - 1,591 ns
- **ObjectGraph:** Python pickle (bytes) - 20,071 ns
- **Person:** Python msgspec (bytes) - 15,678 ns
- **SimpleObject:** Python msgspec (bytes) - 3,091 ns
- **StringArray:** Python orjson (bytes) - 29,223 ns
- **Telemetry:** Python msgspec (bytes) - 15,860 ns

### Performance by Mode (Stream vs String/Bytes)

- **Stream:** C# NetSerializer (Integer) - 2,255 ns
- **bytes:** Python msgspec (Integer) - 1,591 ns
- **stream:** Python msgspec (Integer) - 2,906 ns
- **string:** C# Json.Net (Integer) - 3,260 ns

### Cross-Language Comparison (Same Data Types)

- **EDI_835:** C# MS Bond Fast (34,936 ns) vs Python orjson (22,635 ns) - Python wins (0.65×)
- **Integer:** C# NetSerializer (2,255 ns) vs Python msgspec (1,591 ns) - Python wins (0.71×)
- **ObjectGraph:** C# Ceras (32,586 ns) vs Python pickle (20,071 ns) - Python wins (0.62×)
- **Person:** C# NetSerializer (24,296 ns) vs Python msgspec (15,678 ns) - Python wins (0.65×)
- **SimpleObject:** C# GroBuf (7,573 ns) vs Python msgspec (3,091 ns) - Python wins (0.41×)
- **StringArray:** C# NetSerializer (36,854 ns) vs Python orjson (29,223 ns) - Python wins (0.79×)
- **Telemetry:** C# MS Bond Fast (15,877 ns) vs Python msgspec (15,860 ns) - Python wins (1.00×)

## Pivot Tables


### C#: Avg Total Time (ns) by Serializer and Mode

| serializer | Stream | string |
|---|---|---|
| Ceras | 74,756 | 35,539,006 |
| CsvHelper | 448,483 | 18,518,386 |
| ExtendedXmlSerializer | 16,791 | 31,228,570 |
| FlatSharp | 12,594 | 911,721,849 |
| FsPickler | 75,946 | 81,249,757 |
| FsPicklerJson | 99,000 | 5,871,630 |
| GroBuf | 5,287 | 97,118,894 |
| Hyperion | 61,785 | 33,834,679 |
| Jil | 63,757 | 136,660,806 |
| Json.Net | 135,784 | 125,980 |
| Json.Net (Helper) | 192,475 | 31,513,590 |
| MS Binary | 146,827 | 4,630,190 |
| MS Bond Compact | 36,471 | 51,921,392 |
| MS Bond Fast | 32,551 | 26,272,483 |
| MS Bond Json | 72,736 | 50,515,863 |
| MS DataContract | 121,553 | 18,352,997 |
| MS DataContract Json | 119,354 | 10,696,530 |
| MS XmlSerializer | 129,562 | 22,428,518 |
| MemoryPack | 8,975 | 17,635,323 |
| Migrant | 86,673 | 17,081,746 |
| NetJSON | 54,430 | 30,691,294 |
| NetSerializer | 24,296 | 5,448,199 |
| ProtoBuf | 42,690 | 26,364,316 |
| ServiceStack Json | 169,978 | 40,469,704 |
| ServiceStack Type | 129,981 | 18,886,081 |
| SharpSerializer | 45,908 | 5,510,791 |
| SharpYaml | 755,300 | 28,258,655 |
| SpanJson | 27,921,138 | 43,197,355 |
| Utf8Json | 75,308 | 42,909,434 |
| YAXLib | 6,207,225 | 23,810,031 |
| YamlDotNet | 64,958,443 | 48,189,077 |
| fastJson | 159,820 | 12,632,323 |


### C#: Ops/Sec by Serializer and Data Type

| serializer | EDI_835 | Integer | ObjectGraph | Person | SimpleObject | StringArray | Telemetry |
|---|---|---|---|---|---|---|---|
| Ceras | 88 | 14,564 | 313 | 28 | 74 | 246 | 159 |
| CsvHelper | - | 54 | - | - | 3 | - | - |
| ExtendedXmlSerializer | - | 32 | - | - | - | - | - |
| FlatSharp | - | 1 | - | - | 4 | 4 | - |
| FsPickler | 112 | 31,123 | 162 | 12 | 726 | 101 | 68 |
| FsPicklerJson | 3,915 | 28,377 | 16,609 | 170 | 18,122 | 6,360 | 5,984 |
| GroBuf | - | 10 | - | - | 8,335 | - | - |
| Hyperion | 56 | 144,639 | - | 30 | 345 | 176 | 100 |
| Jil | 16 | 172 | - | 7 | 78 | 98 | 35 |
| Json.Net | 3,664 | 306,778 | 23,399 | 7,938 | 49,500 | 8,301 | 7,337 |
| Json.Net (Helper) | 219 | 55,184 | 356 | 32 | 503 | 533 | 236 |
| MS Binary | 3,432 | 24,653 | 12,429 | 216 | 14,783 | 5,007 | 9,726 |
| MS Bond Compact | 58 | 314 | - | 19 | 138 | 231 | 81 |
| MS Bond Fast | 72 | 65 | - | 38 | 231 | 333 | 110 |
| MS Bond Json | 77 | 546 | - | 20 | 285 | 347 | 88 |
| MS DataContract | 81 | 459 | 195 | 54 | 10,669 | 237 | 132 |
| MS DataContract Json | 87 | 53,841 | - | 93 | 14,497 | 250 | 201 |
| MS XmlSerializer | 122 | 689 | - | 45 | 307 | 216 | 179 |
| MemoryPack | - | 57 | - | - | 35,381 | 313 | - |
| Migrant | - | 59 | - | - | 125 | - | - |
| NetJSON | 99 | 714 | - | 33 | 350 | 397 | 164 |
| NetSerializer | 342 | 162,544 | - | 184 | 74,320 | 15,242 | 14,213 |
| ProtoBuf | 101 | 37,386 | - | 38 | 684 | 264 | 286 |
| ServiceStack Json | 176 | 148,095 | - | 25 | 19,623 | 289 | 124 |
| ServiceStack Type | 204 | 236,428 | - | 53 | 22,228 | 407 | 152 |
| SharpSerializer | 938 | 181 | 4,285 | - | 302 | 1,959 | - |
| SharpYaml | 813 | 29,618 | - | 35 | 3,860 | 1,016 | 261 |
| SpanJson | 44 | 48,537 | - | 23 | 160 | 56 | 77 |
| Utf8Json | 158 | 50,770 | - | 23 | 794 | 187 | 151 |
| YAXLib | 113 | 403 | - | 42 | 2,244 | 1,367 | 170 |
| YamlDotNet | 30 | 8,786 | 219 | 21 | 2,879 | 4 | 3 |
| fastJson | 350 | 55,200 | - | 79 | 19,942 | 8,609 | 478 |


### Python: Avg Total Time (ns) by Serializer and Mode

| serializer | bytes | stream |
|---|---|---|
| avro | 172,483 | 167,878 |
| cbor2 | 417,432 | 413,675 |
| cloudpickle | 201,587 | 193,663 |
| msgpack | 351,154 | 347,700 |
| msgspec | 15,678 | 18,345 |
| orjson | 19,671 | 17,722 |
| pickle | 85,374 | 89,437 |
| protobuf | 183,228 | 188,170 |
| rapidjson | 358,564 | 349,817 |


### Python: Ops/Sec by Serializer and Data Type

| serializer | EDI_835 | Integer | ObjectGraph | Person | SimpleObject | StringArray | Telemetry |
|---|---|---|---|---|---|---|---|
| avro | 3,521 | - | - | 5,798 | 37,627 | 4,531 | 7,865 |
| cbor2 | 1,637 | 54,782 | - | 2,396 | 7,182 | 4,188 | 2,938 |
| cloudpickle | 5,131 | 99,213 | 21,103 | 4,961 | 25,202 | 16,241 | 17,786 |
| msgpack | 2,250 | 349,501 | - | 2,848 | 9,283 | 6,820 | 4,170 |
| msgspec | 38,248 | 628,460 | - | 63,785 | 323,504 | 30,039 | 63,050 |
| orjson | 44,179 | 437,461 | - | 50,835 | 211,998 | 34,220 | 60,225 |
| pickle | 10,341 | 226,084 | 49,822 | 11,713 | 50,683 | 22,672 | 31,047 |
| protobuf | 2,333 | - | - | 5,458 | 45,386 | 8,968 | 21,350 |
| rapidjson | 2,196 | 200,733 | - | 2,789 | 8,973 | 6,646 | 2,917 |


---

*Generated by Serializer Benchmark CI*
