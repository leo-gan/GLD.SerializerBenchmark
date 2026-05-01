# Serializer Benchmark Summary

**Generated:** 2026-05-01T06:13:44.365050

---


## C# / .NET Benchmarks

| Serializer | Test Data | Mode | Avg Total (ns) | Ops/Sec | Size (bytes) |
|------------|-----------|------|----------------|---------|----------------|
| MS Bond Fast | Integer | string | 1,243 | 804,528 | 4 |
| NetSerializer | Integer | string | 2,385 | 419,342 | 8 |
| MS Bond Compact | Integer | string | 3,116 | 320,888 | 4 |
| NetSerializer | Integer | Stream | 3,277 | 305,167 | 6 |
| ServiceStack Type | Integer | string | 3,291 | 303,820 | 10 |
| GroBuf | Integer | string | 3,342 | 299,223 | 8 |
| Json.Net | Integer | string | 3,684 | 271,418 | 10 |
| NetJSON | Integer | string | 3,940 | 253,776 | 10 |
| Hyperion | Integer | string | 4,425 | 225,967 | 8 |
| Json.Net | Integer | Stream | 4,674 | 213,929 | 10 |
| ServiceStack Json | Integer | string | 4,773 | 209,496 | 10 |
| MS Bond Json | Integer | string | 5,363 | 186,469 | 2 |
| MemoryPack | Integer | string | 5,552 | 180,122 | 8 |
| MS Bond Fast | SimpleObject | string | 5,568 | 179,593 | 68 |
| Hyperion | Integer | Stream | 5,889 | 169,821 | 5 |
| ServiceStack Type | Integer | Stream | 6,340 | 157,737 | 10 |
| GroBuf | SimpleObject | Stream | 6,797 | 147,130 | 1 |
| GroBuf | Integer | Stream | 6,977 | 143,329 | 5 |
| NetSerializer | SimpleObject | Stream | 7,076 | 141,332 | 40 |
| Jil | Integer | string | 7,163 | 139,602 | 10 |


## Python Benchmarks

| Serializer | Test Data | Mode | Avg Total (ns) | Ops/Sec | Size (bytes) |
|------------|-----------|------|----------------|---------|----------------|
| msgspec | Integer | bytes | 1,838 | 544,088 | 10 |
| orjson | Integer | bytes | 2,550 | 392,197 | 10 |
| msgspec | Integer | stream | 3,440 | 290,684 | 10 |
| msgpack | Integer | bytes | 3,619 | 276,297 | 5 |
| orjson | Integer | stream | 4,441 | 225,163 | 10 |
| msgspec | SimpleObject | bytes | 4,441 | 225,156 | 102 |
| pickle | Integer | bytes | 5,101 | 196,028 | 17 |
| orjson | SimpleObject | bytes | 5,807 | 172,213 | 102 |
| msgpack | Integer | stream | 6,203 | 161,223 | 5 |
| msgspec | SimpleObject | stream | 6,210 | 161,021 | 102 |
| rapidjson | Integer | bytes | 6,487 | 154,150 | 10 |
| orjson | SimpleObject | stream | 7,710 | 129,694 | 102 |
| rapidjson | Integer | stream | 8,152 | 122,664 | 10 |
| pickle | Integer | stream | 8,810 | 113,512 | 17 |
| msgspec | Person | bytes | 9,825 | 101,781 | 387 |
| orjson | Person | bytes | 10,032 | 99,678 | 387 |
| cloudpickle | Integer | bytes | 11,661 | 85,757 | 17 |
| msgspec | Person | stream | 12,190 | 82,037 | 387 |
| orjson | Person | stream | 12,491 | 80,058 | 387 |
| cloudpickle | Integer | stream | 12,813 | 78,046 | 17 |


## Top Performers by Language

### Fastest Serializers (by total time)

- **C#:** MS Bond Fast - 1,243 ns
- **Python:** msgspec - 1,838 ns

### Most Compact Output (by size)

- **C#:** MS Bond Compact - 1 bytes
- **Python:** msgpack - 5 bytes

## Multidimensional Analysis

### Best Performers by Data Type

- **EDI_835:** C# MS Bond Fast (string) - 19,450 ns
- **Integer:** C# MS Bond Fast (string) - 1,243 ns
- **ObjectGraph:** C# Json.Net (Stream) - 15,057 ns
- **Person:** Python msgspec (bytes) - 9,825 ns
- **SimpleObject:** Python msgspec (bytes) - 4,441 ns
- **StringArray:** C# MS Bond Fast (Stream) - 25,322 ns
- **Telemetry:** C# MS Bond Fast (string) - 10,123 ns

### Performance by Mode (Stream vs String/Bytes)

- **Stream:** C# NetSerializer (Integer) - 3,277 ns
- **bytes:** Python msgspec (Integer) - 1,838 ns
- **stream:** Python msgspec (Integer) - 3,440 ns
- **string:** C# MS Bond Fast (Integer) - 1,243 ns

### Cross-Language Comparison (Same Data Types)

- **EDI_835:** C# MS Bond Fast (19,450 ns) vs Python orjson (22,730 ns) - C# wins (1.17×)
- **Integer:** C# MS Bond Fast (1,243 ns) vs Python msgspec (1,838 ns) - C# wins (1.48×)
- **ObjectGraph:** C# Json.Net (15,057 ns) vs Python pickle (23,061 ns) - C# wins (1.53×)
- **Person:** C# MS Bond Fast (13,412 ns) vs Python msgspec (9,825 ns) - Python wins (0.73×)
- **SimpleObject:** C# MS Bond Fast (5,568 ns) vs Python msgspec (4,441 ns) - Python wins (0.80×)
- **StringArray:** C# MS Bond Fast (25,322 ns) vs Python orjson (37,177 ns) - C# wins (1.47×)
- **Telemetry:** C# MS Bond Fast (10,123 ns) vs Python orjson (17,338 ns) - C# wins (1.71×)

## Pivot Tables


### C#: Avg Total Time (ns) by Serializer and Mode

| serializer | Stream | string |
|---|---|---|
| Ceras | 80,487 | 67,322 |
| CsvHelper | 575,677 | 443,243 |
| ExtendedXmlSerializer | 22,645 | 15,612 |
| FlatSharp | 14,093 | 7,762 |
| FsPickler | 84,944 | 71,369 |
| FsPicklerJson | 124,996 | 113,079 |
| GroBuf | 6,977 | 3,342 |
| Hyperion | 61,024 | 58,699 |
| Jil | 67,819 | 61,116 |
| Json.Net | 152,721 | 131,351 |
| Json.Net (Helper) | 233,699 | 193,144 |
| MS Binary | 215,550 | 196,973 |
| MS Bond Compact | 33,274 | 18,760 |
| MS Bond Fast | 25,880 | 13,412 |
| MS Bond Json | 81,213 | 67,146 |
| MS DataContract | 186,564 | 134,567 |
| MS DataContract Json | 211,462 | 137,633 |
| MS XmlSerializer | 171,433 | 131,338 |
| MemoryPack | 10,935 | 5,552 |
| Migrant | 68,154 | 47,620 |
| NetJSON | 61,831 | 53,719 |
| NetSerializer | 25,395 | 28,985 |
| ProtoBuf | 49,152 | 47,161 |
| ServiceStack Json | 164,362 | 156,885 |
| ServiceStack Type | 132,516 | 132,870 |
| SharpSerializer | 59,469 | 45,683 |
| SharpYaml | 819,524 | 791,924 |
| SpanJson | 54,209 | 40,666 |
| Utf8Json | 69,472 | 69,479 |
| YAXLib | 1,093,006 | 986,592 |
| YamlDotNet | 1,442,154 | 1,344,936 |
| fastJson | 187,900 | 171,458 |


### C#: Ops/Sec by Serializer and Data Type

| serializer | EDI_835 | Integer | ObjectGraph | Person | SimpleObject | StringArray | Telemetry |
|---|---|---|---|---|---|---|---|
| Ceras | 12,408 | 64,609 | 30,536 | 14,854 | 22,862 | 10,898 | 13,346 |
| CsvHelper | - | 2,256 | - | - | 3 | - | - |
| ExtendedXmlSerializer | - | 64,054 | - | - | - | - | - |
| FlatSharp | - | 128,838 | - | - | 40,684 | 14,693 | - |
| FsPickler | 12,622 | 48,833 | 27,119 | 14,012 | 24,011 | 12,780 | 14,342 |
| FsPicklerJson | 7,729 | 27,562 | 22,128 | 8,843 | 16,963 | 9,497 | 4,125 |
| GroBuf | - | 299,223 | - | - | 137,771 | - | - |
| Hyperion | 13,508 | 225,967 | - | 17,036 | 42,550 | 11,314 | 17,318 |
| Jil | 11,204 | 139,602 | - | 16,362 | 53,328 | 11,445 | 4,870 |
| Json.Net | 15,694 | 271,418 | 63,142 | 7,613 | 49,141 | 12,528 | 4,550 |
| Json.Net (Helper) | 9,029 | 76,970 | 26,319 | 5,177 | 16,655 | 8,072 | 3,552 |
| MS Binary | 4,813 | 31,062 | 12,833 | 5,077 | 17,007 | 8,254 | 9,446 |
| MS Bond Compact | 39,129 | 320,888 | - | 53,306 | 102,108 | 26,851 | 57,921 |
| MS Bond Fast | 51,414 | 804,528 | - | 74,557 | 179,593 | 30,717 | 98,785 |
| MS Bond Json | 16,630 | 186,469 | - | 14,893 | 40,250 | 21,066 | 5,723 |
| MS DataContract | 7,695 | 43,104 | 17,450 | 7,431 | 12,952 | 5,133 | 2,792 |
| MS DataContract Json | 8,282 | 62,988 | - | 7,266 | 17,236 | 5,983 | 3,183 |
| MS XmlSerializer | 7,795 | 37,880 | - | 7,614 | 13,043 | 4,615 | 2,923 |
| MemoryPack | - | 180,122 | - | - | 57,742 | 16,918 | - |
| Migrant | - | 21,000 | - | - | 5,450 | - | - |
| NetJSON | 18,645 | 253,776 | - | 18,615 | 46,905 | 14,089 | 7,104 |
| NetSerializer | 24,342 | 419,342 | - | 34,501 | 107,701 | 22,277 | 18,276 |
| ProtoBuf | 20,567 | 89,288 | - | 21,204 | 42,097 | 13,440 | 21,884 |
| ServiceStack Json | 6,686 | 209,496 | - | 6,374 | 22,681 | 7,965 | 3,823 |
| ServiceStack Type | 8,400 | 303,820 | - | 7,526 | 22,664 | 9,973 | 4,572 |
| SharpSerializer | 1,048 | 21,890 | 4,073 | - | 7,474 | 2,056 | - |
| SharpYaml | 1,267 | 35,840 | - | 1,263 | 3,654 | 1,033 | 1,073 |
| SpanJson | 16,772 | 131,138 | - | 24,590 | 34,472 | 15,126 | 7,284 |
| Utf8Json | 8,370 | 113,470 | - | 14,393 | 30,183 | 10,959 | 3,776 |
| YAXLib | 990 | 9,102 | - | 1,014 | 2,139 | 1,484 | 917 |
| YamlDotNet | 1,298 | 12,491 | 5,377 | 744 | 2,752 | 4 | 5 |
| fastJson | 7,766 | 91,808 | - | 5,832 | 22,888 | 11,984 | 4,314 |


### Python: Avg Total Time (ns) by Serializer and Mode

| serializer | bytes | stream |
|---|---|---|
| avro | 96,178 | 95,136 |
| cbor2 | 318,576 | 328,590 |
| cloudpickle | 134,079 | 137,456 |
| msgpack | 263,091 | 275,101 |
| msgspec | 9,825 | 12,190 |
| orjson | 10,032 | 12,491 |
| pickle | 54,350 | 59,981 |
| protobuf | 88,305 | 90,755 |
| rapidjson | 268,884 | 270,553 |


### Python: Ops/Sec by Serializer and Data Type

| serializer | EDI_835 | Integer | ObjectGraph | Person | SimpleObject | StringArray | Telemetry |
|---|---|---|---|---|---|---|---|
| avro | 2,737 | - | - | 10,397 | 38,071 | 3,900 | 5,340 |
| cbor2 | 1,200 | 44,955 | - | 3,139 | 5,805 | 2,858 | 2,647 |
| cloudpickle | 3,999 | 85,757 | 19,351 | 7,458 | 20,062 | 13,231 | 13,892 |
| msgpack | 1,780 | 276,297 | - | 3,801 | 8,525 | 5,606 | 3,762 |
| msgspec | 33,046 | 544,088 | - | 101,781 | 225,156 | 23,109 | 50,077 |
| orjson | 43,995 | 392,197 | - | 99,678 | 172,213 | 26,899 | 57,678 |
| pickle | 9,177 | 196,028 | 43,363 | 18,399 | 52,437 | 17,954 | 22,291 |
| protobuf | 1,767 | - | - | 11,324 | 33,253 | 7,838 | 15,974 |
| rapidjson | 1,788 | 154,150 | - | 3,719 | 7,343 | 5,071 | 2,428 |


---

*Generated by Serializer Benchmark CI*
