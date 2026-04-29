# Serializer Benchmark Summary

**Generated:** 2026-04-28T16:08:31.851057

---


## C# / .NET Benchmarks

| Serializer | Test Data | Mode | Avg Total (ns) | Ops/Sec | Size (bytes) |
|------------|-----------|------|----------------|---------|----------------|
| MS Bond Fast | Integer | string | 1,293 | 773,149 | 4 |
| NetSerializer | Integer | Stream | 1,866 | 535,990 | 6 |
| NetSerializer | Integer | string | 2,331 | 429,066 | 8 |
| MS Bond Compact | Integer | string | 2,808 | 356,167 | 4 |
| ServiceStack Type | Integer | string | 3,289 | 304,053 | 10 |
| Json.Net | Integer | string | 3,405 | 293,705 | 10 |
| GroBuf | Integer | string | 3,441 | 290,604 | 8 |
| Hyperion | Integer | Stream | 3,506 | 285,185 | 5 |
| GroBuf | Integer | Stream | 3,510 | 284,909 | 5 |
| NetJSON | Integer | string | 4,187 | 238,840 | 10 |
| ServiceStack Type | Integer | Stream | 4,309 | 232,067 | 10 |
| Json.Net | Integer | Stream | 4,400 | 227,292 | 10 |
| Hyperion | Integer | string | 4,474 | 223,508 | 8 |
| ServiceStack Json | Integer | string | 4,749 | 210,576 | 10 |
| MS Bond Fast | SimpleObject | string | 5,247 | 190,586 | 68 |
| MemoryPack | Integer | string | 5,464 | 183,013 | 8 |
| MS Bond Json | Integer | string | 5,565 | 179,697 | 2 |
| NetJSON | Integer | Stream | 5,723 | 174,737 | 10 |
| MemoryPack | Integer | Stream | 6,057 | 165,093 | 5 |
| ServiceStack Json | Integer | Stream | 6,998 | 142,893 | 10 |


## Python Benchmarks

| Serializer | Test Data | Mode | Avg Total (ns) | Ops/Sec | Size (bytes) |
|------------|-----------|------|----------------|---------|----------------|
| msgspec | Integer | bytes | 1,458 | 685,675 | 10 |
| orjson | Integer | bytes | 2,051 | 487,675 | 10 |
| msgspec | Integer | stream | 2,779 | 359,809 | 10 |
| msgpack | Integer | bytes | 2,883 | 346,845 | 5 |
| msgspec | SimpleObject | bytes | 3,054 | 327,476 | 102 |
| orjson | Integer | stream | 3,610 | 277,045 | 10 |
| pickle | Integer | bytes | 4,493 | 222,586 | 17 |
| msgspec | SimpleObject | stream | 4,588 | 217,938 | 102 |
| orjson | SimpleObject | bytes | 4,793 | 208,617 | 102 |
| rapidjson | Integer | bytes | 5,125 | 195,111 | 10 |
| msgpack | Integer | stream | 5,221 | 191,551 | 5 |
| orjson | SimpleObject | stream | 6,372 | 156,925 | 102 |
| rapidjson | Integer | stream | 6,430 | 155,532 | 10 |
| pickle | Integer | stream | 7,506 | 133,223 | 17 |
| cloudpickle | Integer | bytes | 10,001 | 99,988 | 17 |
| cloudpickle | Integer | stream | 11,178 | 89,459 | 17 |
| orjson | Telemetry | bytes | 15,133 | 66,081 | 2,198 |
| orjson | Person | bytes | 16,638 | 60,102 | 919 |
| msgspec | Person | bytes | 18,097 | 55,257 | 919 |
| orjson | Telemetry | stream | 18,137 | 55,137 | 2,198 |


## Top Performers by Language

### Fastest Serializers (by total time)

- **C#:** MS Bond Fast - 1,293 ns
- **Python:** msgspec - 1,458 ns

### Most Compact Output (by size)

- **C#:** MS Bond Compact - 1 bytes
- **Python:** msgpack - 5 bytes

## Multidimensional Analysis

### Best Performers by Data Type

- **EDI_835:** C# MS Bond Fast (string) - 22,996 ns
- **Integer:** C# MS Bond Fast (string) - 1,293 ns
- **ObjectGraph:** C# Json.Net (string) - 13,235 ns
- **Person:** C# MS Bond Fast (string) - 12,569 ns
- **SimpleObject:** Python msgspec (bytes) - 3,054 ns
- **StringArray:** Python orjson (bytes) - 32,312 ns
- **Telemetry:** C# MS Bond Fast (string) - 8,849 ns

### Performance by Mode (Stream vs String/Bytes)

- **Stream:** C# NetSerializer (Integer) - 1,866 ns
- **bytes:** Python msgspec (Integer) - 1,458 ns
- **stream:** Python msgspec (Integer) - 2,779 ns
- **string:** C# MS Bond Fast (Integer) - 1,293 ns

### Cross-Language Comparison (Same Data Types)

- **EDI_835:** C# MS Bond Fast (22,996 ns) vs Python orjson (26,026 ns) - C# wins (1.13×)
- **Integer:** C# MS Bond Fast (1,293 ns) vs Python msgspec (1,458 ns) - C# wins (1.13×)
- **ObjectGraph:** C# Json.Net (13,235 ns) vs Python pickle (19,864 ns) - C# wins (1.50×)
- **Person:** C# MS Bond Fast (12,569 ns) vs Python orjson (16,638 ns) - C# wins (1.32×)
- **SimpleObject:** C# MS Bond Fast (5,247 ns) vs Python msgspec (3,054 ns) - Python wins (0.58×)
- **StringArray:** C# MS Bond Fast (32,337 ns) vs Python orjson (32,312 ns) - Python wins (1.00×)
- **Telemetry:** C# MS Bond Fast (8,849 ns) vs Python orjson (15,133 ns) - C# wins (1.71×)

## Pivot Tables


### C#: Avg Total Time (ns) by Serializer and Mode

| serializer | Stream | string |
|---|---|---|
| Ceras | 69,629 | 65,441 |
| CsvHelper | 419,815 | 417,879 |
| ExtendedXmlSerializer | 15,570 | 14,914 |
| FlatSharp | 7,229 | 7,235 |
| FsPickler | 75,215 | 65,294 |
| FsPicklerJson | 130,531 | 113,530 |
| GroBuf | 3,510 | 3,441 |
| Hyperion | 55,240 | 53,857 |
| Jil | 75,413 | 65,333 |
| Json.Net | 191,017 | 126,892 |
| Json.Net (Helper) | 260,589 | 186,366 |
| MS Binary | 168,878 | 144,561 |
| MS Bond Compact | 24,856 | 16,128 |
| MS Bond Fast | 19,681 | 12,569 |
| MS Bond Json | 83,070 | 65,619 |
| MS DataContract | 125,450 | 132,166 |
| MS DataContract Json | 128,484 | 130,833 |
| MS XmlSerializer | 178,280 | 175,005 |
| MemoryPack | 6,057 | 5,464 |
| Migrant | 43,897 | 45,536 |
| NetJSON | 64,319 | 58,699 |
| NetSerializer | 26,689 | 27,945 |
| ProtoBuf | 45,532 | 43,985 |
| ServiceStack Json | 165,917 | 156,866 |
| ServiceStack Type | 135,828 | 136,644 |
| SharpSerializer | 40,909 | 42,637 |
| SharpYaml | 792,222 | 741,856 |
| SpanJson | 50,398 | 43,512 |
| Utf8Json | 68,868 | 72,679 |
| YAXLib | 996,052 | 893,760 |
| YamlDotNet | 1,412,790 | 1,248,686 |
| fastJson | 204,717 | 142,846 |


### C#: Ops/Sec by Serializer and Data Type

| serializer | EDI_835 | Integer | ObjectGraph | Person | SimpleObject | StringArray | Telemetry |
|---|---|---|---|---|---|---|---|
| Ceras | 12,846 | 67,261 | 38,175 | 15,281 | 22,178 | 11,012 | 13,666 |
| CsvHelper | - | 2,393 | - | - | 3 | - | - |
| ExtendedXmlSerializer | - | 67,053 | - | - | - | - | - |
| FlatSharp | - | 138,222 | - | - | 38,799 | 15,347 | - |
| FsPickler | 12,499 | 50,104 | 36,994 | 15,315 | 21,548 | 10,405 | 14,368 |
| FsPicklerJson | 7,312 | 27,652 | 26,760 | 8,808 | 15,648 | 7,706 | 4,273 |
| GroBuf | - | 290,604 | - | - | 137,802 | - | - |
| Hyperion | 14,053 | 223,508 | - | 18,568 | 42,639 | 10,695 | 16,219 |
| Jil | 11,543 | 131,125 | - | 15,306 | 53,856 | 12,121 | 5,157 |
| Json.Net | 13,993 | 293,705 | 75,554 | 7,881 | 46,223 | 9,440 | 4,756 |
| Json.Net (Helper) | 8,342 | 72,603 | 34,008 | 5,366 | 14,859 | 6,923 | 3,662 |
| MS Binary | 3,937 | 32,979 | 14,402 | 6,917 | 13,609 | 5,967 | 9,985 |
| MS Bond Compact | 34,253 | 356,167 | - | 62,005 | 103,761 | 22,487 | 59,758 |
| MS Bond Fast | 43,486 | 773,149 | - | 79,563 | 190,586 | 25,395 | 113,012 |
| MS Bond Json | 15,741 | 179,697 | - | 15,239 | 37,704 | 14,349 | 6,157 |
| MS DataContract | 4,188 | 46,988 | 21,714 | 7,566 | 11,607 | 3,668 | 4,015 |
| MS DataContract Json | 3,260 | 70,942 | - | 7,643 | 16,146 | 4,110 | 4,939 |
| MS XmlSerializer | 6,106 | 42,235 | - | 5,714 | 13,174 | 5,579 | 3,432 |
| MemoryPack | - | 183,013 | - | - | 59,444 | 17,129 | - |
| Migrant | - | 21,961 | - | - | 5,134 | - | - |
| NetJSON | 18,156 | 238,840 | - | 17,036 | 47,335 | 14,263 | 7,506 |
| NetSerializer | 24,458 | 429,066 | - | 35,785 | 104,531 | 19,804 | 15,843 |
| ProtoBuf | 20,904 | 90,734 | - | 22,735 | 38,135 | 12,734 | 21,318 |
| ServiceStack Json | 6,807 | 210,576 | - | 6,375 | 22,790 | 8,754 | 3,715 |
| ServiceStack Type | 8,442 | 304,053 | - | 7,318 | 23,858 | 10,933 | 4,507 |
| SharpSerializer | 1,111 | 23,454 | 4,995 | - | 7,460 | 2,401 | - |
| SharpYaml | 1,061 | 38,576 | - | 1,348 | 3,459 | 1,066 | 1,129 |
| SpanJson | 16,182 | 128,735 | - | 22,982 | 33,746 | 15,722 | 7,696 |
| Utf8Json | 8,412 | 110,252 | - | 13,759 | 27,551 | 11,075 | 3,635 |
| YAXLib | 947 | 9,830 | - | 1,119 | 2,027 | 1,536 | 930 |
| YamlDotNet | 1,125 | 13,316 | 6,001 | 801 | 2,586 | 4 | 5 |
| fastJson | 7,786 | 98,623 | - | 7,001 | 20,978 | 10,151 | 4,312 |


### Python: Avg Total Time (ns) by Serializer and Mode

| serializer | bytes | stream |
|---|---|---|
| avro | 191,993 | 186,495 |
| cbor2 | 473,325 | 463,476 |
| cloudpickle | 221,025 | 220,190 |
| msgpack | 376,178 | 382,255 |
| msgspec | 18,097 | 20,361 |
| orjson | 16,638 | 20,051 |
| pickle | 89,910 | 96,911 |
| protobuf | 193,597 | 201,847 |
| rapidjson | 390,000 | 397,690 |


### Python: Ops/Sec by Serializer and Data Type

| serializer | EDI_835 | Integer | ObjectGraph | Person | SimpleObject | StringArray | Telemetry |
|---|---|---|---|---|---|---|---|
| avro | 3,368 | - | - | 5,209 | 34,010 | 3,015 | 7,107 |
| cbor2 | 1,618 | 53,028 | - | 2,113 | 5,862 | 3,870 | 2,782 |
| cloudpickle | 4,580 | 99,988 | 22,796 | 4,524 | 25,801 | 13,754 | 17,192 |
| msgpack | 2,107 | 346,845 | - | 2,658 | 9,715 | 6,359 | 4,062 |
| msgspec | 16,274 | 685,675 | - | 55,257 | 327,476 | 27,564 | 54,650 |
| orjson | 38,424 | 487,675 | - | 60,102 | 208,617 | 30,948 | 66,081 |
| pickle | 10,054 | 222,586 | 50,343 | 11,122 | 52,766 | 11,186 | 30,992 |
| protobuf | 2,165 | - | - | 5,165 | 45,507 | 9,415 | 20,015 |
| rapidjson | 1,898 | 195,111 | - | 2,564 | 8,906 | 6,126 | 2,725 |


---

*Generated by Serializer Benchmark CI*
