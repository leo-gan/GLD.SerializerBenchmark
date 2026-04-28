# Serializer Benchmark Summary

**Generated:** 2026-04-27T21:05:41.458368

---


## C# / .NET Benchmarks

| Serializer | Test Data | Mode | Avg Total (ns) | Ops/Sec | Size (bytes) |
|------------|-----------|------|----------------|---------|----------------|
| MS Bond Fast | Integer | string | 1,581 | 632,630 | 4 |
| NetSerializer | Integer | Stream | 2,004 | 499,054 | 6 |
| NetSerializer | Integer | string | 2,984 | 335,119 | 8 |
| Json.Net | Integer | string | 3,197 | 312,820 | 10 |
| Hyperion | Integer | Stream | 3,532 | 283,089 | 5 |
| MS Bond Compact | Integer | string | 3,534 | 282,982 | 4 |
| Json.Net | Integer | Stream | 3,880 | 257,718 | 10 |
| GroBuf | Integer | Stream | 3,880 | 257,712 | 5 |
| MS Bond Fast | SimpleObject | string | 3,938 | 253,939 | 68 |
| ServiceStack Type | Integer | string | 4,011 | 249,323 | 10 |
| ServiceStack Type | Integer | Stream | 4,310 | 232,036 | 10 |
| GroBuf | Integer | string | 4,427 | 225,898 | 8 |
| NetJSON | Integer | string | 4,902 | 204,002 | 10 |
| Hyperion | Integer | string | 5,454 | 183,345 | 8 |
| NetJSON | Integer | Stream | 5,631 | 177,602 | 10 |
| MS Bond Json | Integer | string | 5,681 | 176,012 | 2 |
| MS Bond Json | Integer | Stream | 5,807 | 172,200 | 2 |
| GroBuf | SimpleObject | string | 5,818 | 171,885 | 4 |
| ServiceStack Json | Integer | string | 6,133 | 163,050 | 10 |
| GroBuf | SimpleObject | Stream | 6,715 | 148,913 | 1 |


## Python Benchmarks

| Serializer | Test Data | Mode | Avg Total (ns) | Ops/Sec | Size (bytes) |
|------------|-----------|------|----------------|---------|----------------|
| msgspec | Integer | bytes | 1,477 | 677,263 | 10 |
| orjson | Integer | bytes | 2,081 | 480,483 | 10 |
| msgpack | Integer | bytes | 2,734 | 365,709 | 5 |
| msgspec | Integer | stream | 2,830 | 353,306 | 10 |
| msgspec | SimpleObject | bytes | 2,955 | 338,383 | 102 |
| orjson | Integer | stream | 3,662 | 273,104 | 10 |
| pickle | Integer | bytes | 4,180 | 239,245 | 17 |
| msgspec | SimpleObject | stream | 4,261 | 234,673 | 102 |
| orjson | SimpleObject | bytes | 4,393 | 227,643 | 102 |
| msgpack | Integer | stream | 4,650 | 215,063 | 5 |
| rapidjson | Integer | bytes | 4,738 | 211,048 | 10 |
| orjson | SimpleObject | stream | 5,773 | 173,222 | 102 |
| rapidjson | Integer | stream | 5,911 | 169,181 | 10 |
| pickle | Integer | stream | 7,043 | 141,985 | 17 |
| cloudpickle | Integer | bytes | 9,875 | 101,270 | 17 |
| cloudpickle | Integer | stream | 13,410 | 74,572 | 17 |
| msgspec | Person | bytes | 14,758 | 67,761 | 908 |
| msgspec | Telemetry | bytes | 15,489 | 64,563 | 2,187 |
| orjson | Telemetry | bytes | 15,658 | 63,864 | 2,187 |
| orjson | Telemetry | stream | 15,794 | 63,313 | 2,187 |


## Top Performers by Language

### Fastest Serializers (by total time)

- **C#:** MS Bond Fast - 1,581 ns
- **Python:** msgspec - 1,477 ns

### Most Compact Output (by size)

- **C#:** MS Bond Compact - 1 bytes
- **Python:** msgpack - 5 bytes

## Multidimensional Analysis

### Best Performers by Data Type

- **EDI_835:** Python orjson (bytes) - 22,009 ns
- **Integer:** Python msgspec (bytes) - 1,477 ns
- **ObjectGraph:** Python pickle (bytes) - 18,995 ns
- **Person:** C# MS Bond Fast (string) - 12,306 ns
- **SimpleObject:** Python msgspec (bytes) - 2,955 ns
- **StringArray:** Python orjson (bytes) - 29,113 ns
- **Telemetry:** C# MS Bond Fast (string) - 8,681 ns

### Performance by Mode (Stream vs String/Bytes)

- **Stream:** C# NetSerializer (Integer) - 2,004 ns
- **bytes:** Python msgspec (Integer) - 1,477 ns
- **stream:** Python msgspec (Integer) - 2,830 ns
- **string:** C# MS Bond Fast (Integer) - 1,581 ns

### Cross-Language Comparison (Same Data Types)

- **EDI_835:** C# MS Bond Fast (23,615 ns) vs Python orjson (22,009 ns) - Python wins (0.93×)
- **Integer:** C# MS Bond Fast (1,581 ns) vs Python msgspec (1,477 ns) - Python wins (0.93×)
- **ObjectGraph:** C# FsPickler (31,355 ns) vs Python pickle (18,995 ns) - Python wins (0.61×)
- **Person:** C# MS Bond Fast (12,306 ns) vs Python msgspec (14,758 ns) - C# wins (1.20×)
- **SimpleObject:** C# MS Bond Fast (3,938 ns) vs Python msgspec (2,955 ns) - Python wins (0.75×)
- **StringArray:** C# MS Bond Fast (34,565 ns) vs Python orjson (29,113 ns) - Python wins (0.84×)
- **Telemetry:** C# MS Bond Fast (8,681 ns) vs Python msgspec (15,489 ns) - C# wins (1.78×)

## Pivot Tables


### C#: Avg Total Time (ns) by Serializer and Mode

| serializer | Stream | string |
|---|---|---|
| Ceras | 69,524 | 67,778 |
| CsvHelper | 435,246 | 484,188 |
| ExtendedXmlSerializer | 14,678 | 18,385 |
| FlatSharp | 8,331 | 9,686 |
| FsPickler | 71,620 | 67,093 |
| FsPicklerJson | 95,818 | 110,380 |
| GroBuf | 3,880 | 4,427 |
| Hyperion | 60,878 | 54,232 |
| Jil | 62,582 | 63,442 |
| Json.Net | 123,262 | 123,985 |
| Json.Net (Helper) | 189,906 | 186,463 |
| MS Binary | 141,537 | 141,897 |
| MS Bond Compact | 26,540 | 16,462 |
| MS Bond Fast | 20,448 | 12,306 |
| MS Bond Json | 60,961 | 65,001 |
| MS DataContract | 114,023 | 124,264 |
| MS DataContract Json | 119,354 | 126,758 |
| MS XmlSerializer | 124,816 | 125,840 |
| MemoryPack | 7,466 | 6,955 |
| Migrant | 46,396 | 54,322 |
| NetJSON | 52,203 | 54,595 |
| NetSerializer | 23,548 | 25,480 |
| ProtoBuf | 41,024 | 42,613 |
| ServiceStack Json | 152,499 | 158,058 |
| ServiceStack Type | 127,319 | 132,250 |
| SharpSerializer | 44,001 | 46,625 |
| SharpYaml | 755,300 | 724,359 |
| SpanJson | 49,846 | 40,953 |
| Utf8Json | 68,548 | 66,316 |
| YAXLib | 930,118 | 903,465 |
| YamlDotNet | 64,958,443 | 1,190,728 |
| fastJson | 159,820 | 141,541 |


### C#: Ops/Sec by Serializer and Data Type

| serializer | EDI_835 | Integer | ObjectGraph | Person | SimpleObject | StringArray | Telemetry |
|---|---|---|---|---|---|---|---|
| Ceras | 11,150 | 57,438 | 31,819 | 14,754 | 26,015 | 10,184 | 15,317 |
| CsvHelper | - | 2,065 | - | - | 4 | - | - |
| ExtendedXmlSerializer | - | 54,392 | - | - | - | - | - |
| FlatSharp | - | 103,241 | - | - | 52,731 | 13,474 | - |
| FsPickler | 9,877 | 43,460 | 31,893 | 14,905 | 25,526 | 9,276 | 15,874 |
| FsPicklerJson | 3,936 | 29,333 | 17,930 | 9,060 | 18,804 | 6,539 | 6,666 |
| GroBuf | - | 225,898 | - | - | 171,885 | - | - |
| Hyperion | 13,313 | 183,345 | - | 18,439 | 56,350 | 9,847 | 18,179 |
| Jil | 8,403 | 118,713 | - | 15,762 | 55,479 | 11,030 | 6,709 |
| Json.Net | 3,728 | 312,820 | 24,501 | 8,065 | 52,289 | 8,411 | 7,501 |
| Json.Net (Helper) | 2,902 | 61,383 | 14,997 | 5,363 | 17,484 | 5,950 | 5,272 |
| MS Binary | 3,667 | 27,947 | 13,962 | 7,047 | 16,064 | 5,276 | 10,979 |
| MS Bond Compact | 34,232 | 282,982 | - | 60,745 | 144,306 | 21,549 | 60,624 |
| MS Bond Fast | 42,346 | 632,630 | - | 81,263 | 253,939 | 24,962 | 115,190 |
| MS Bond Json | 7,198 | 176,012 | - | 15,384 | 41,855 | 13,170 | 9,742 |
| MS DataContract | 4,062 | 38,643 | 19,426 | 8,047 | 14,178 | 3,428 | 4,759 |
| MS DataContract Json | 3,274 | 59,771 | - | 7,889 | 19,061 | 3,922 | 5,719 |
| MS XmlSerializer | 3,891 | 37,604 | - | 7,947 | 14,404 | 3,686 | 4,506 |
| MemoryPack | - | 143,780 | - | - | 71,154 | 15,852 | - |
| Migrant | - | 18,409 | - | - | 6,413 | - | - |
| NetJSON | 14,743 | 204,002 | - | 18,317 | 52,479 | 13,473 | 9,585 |
| NetSerializer | 24,188 | 335,119 | - | 39,247 | 133,540 | 17,878 | 16,638 |
| ProtoBuf | 17,030 | 76,345 | - | 23,467 | 46,650 | 11,659 | 26,525 |
| ServiceStack Json | 3,891 | 163,050 | - | 6,327 | 25,961 | 7,784 | 5,225 |
| ServiceStack Type | 4,869 | 249,323 | - | 7,561 | 27,641 | 10,030 | 5,863 |
| SharpSerializer | 960 | 21,448 | 4,721 | - | 8,751 | 2,076 | - |
| SharpYaml | 825 | 32,465 | - | 1,381 | 4,020 | 1,045 | 1,110 |
| SpanJson | 14,379 | 107,251 | - | 24,418 | 42,429 | 14,101 | 10,402 |
| Utf8Json | 8,757 | 91,746 | - | 15,079 | 38,512 | 10,462 | 3,951 |
| YAXLib | 742 | 7,821 | - | 1,107 | 2,331 | 1,420 | 920 |
| YamlDotNet | 867 | 10,031 | 5,792 | 840 | 2,971 | 4 | 3 |
| fastJson | 4,782 | 85,373 | - | 7,065 | 24,081 | 9,595 | 5,135 |


### Python: Avg Total Time (ns) by Serializer and Mode

| serializer | bytes | stream |
|---|---|---|
| avro | 168,944 | 165,257 |
| cbor2 | 410,710 | 408,548 |
| cloudpickle | 198,744 | 192,366 |
| msgpack | 349,353 | 343,811 |
| msgspec | 14,758 | 18,345 |
| orjson | 17,360 | 17,603 |
| pickle | 84,100 | 87,834 |
| protobuf | 180,171 | 182,452 |
| rapidjson | 353,671 | 349,817 |


### Python: Ops/Sec by Serializer and Data Type

| serializer | EDI_835 | Integer | ObjectGraph | Person | SimpleObject | StringArray | Telemetry |
|---|---|---|---|---|---|---|---|
| avro | 3,578 | - | - | 5,919 | 39,318 | 4,555 | 7,924 |
| cbor2 | 1,743 | 56,327 | - | 2,435 | 7,392 | 4,235 | 2,985 |
| cloudpickle | 5,184 | 101,270 | 21,456 | 5,032 | 26,075 | 16,890 | 18,287 |
| msgpack | 2,279 | 365,709 | - | 2,862 | 9,394 | 6,935 | 4,306 |
| msgspec | 39,696 | 677,263 | - | 67,761 | 338,383 | 30,700 | 64,563 |
| orjson | 45,435 | 480,483 | - | 57,605 | 227,643 | 34,348 | 63,864 |
| pickle | 10,810 | 239,245 | 52,646 | 11,891 | 52,404 | 23,234 | 32,011 |
| protobuf | 2,385 | - | - | 5,550 | 47,585 | 9,182 | 22,017 |
| rapidjson | 2,249 | 211,048 | - | 2,827 | 9,139 | 6,687 | 2,966 |


---

*Generated by Serializer Benchmark CI*
