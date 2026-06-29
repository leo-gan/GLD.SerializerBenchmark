# C# Tested Serializers

Complete reference for all **38 serializers** registered in `c-sharp/src/Program.cs`, organized by category.

**Not in this suite:** System.Text.Json, MessagePack-CSharp, Wire — mentioned in ecosystem overviews only.

## Table of Contents
- [Microsoft Built-in](#microsoft-built-in)
- [Microsoft Bond](#microsoft-bond)
- [JSON Serializers](#json-serializers)
- [Binary Serializers](#binary-serializers)
- [XML Serializers](#xml-serializers)
- [YAML Serializers](#yaml-serializers)
- [Specialized/High-Performance](#specializedhigh-performance)
- [Partial coverage / limitations](#partially-tested-serializers)

---

## Microsoft Built-in

### BinarySerializer (`MS Binary`)
- **Type**: Binary
- **Status**: ✅ Registered and run (legacy BinaryFormatter path)
- **Description**: Microsoft's legacy binary formatter. Simple binary serialization for .NET objects.
- **Limitations**: Limited type support, security concerns with untrusted data.

### DataContractSerializer
- **Type**: XML
- **Status**: ✅ All benchmark passed
- **Description**: Microsoft's WCF-era serializer. Uses DataContract attributes for explicit schema control.
- **Best For**: WCF services, interop scenarios requiring explicit contracts.

### DataContractJsonSerializer
- **Type**: JSON
- **Status**: ✅ All benchmark passed
- **Description**: JSON variant of DataContractSerializer. Part of .NET framework.
- **Best For**: WCF REST services, Microsoft stack compatibility.

### XmlSerializer
- **Type**: XML
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: Classic .NET XML serializer. Requires public parameterless constructors.
- **Best For**: XML-based APIs, SOAP services, configuration files.
- **Limitations**: Does not support circular references (ObjectGraph).

---

## Microsoft Bond

Bond serializers are **registered** in `Program.cs` and use Bond-generated types under `src/Bond/`. They require Bond schema attributes on the model types used for those paths; partial data-type coverage is listed below.

### MS Bond Compact
- **Type**: Binary (Bond Compact Binary)
- **Status**: ⚠️ Partial data coverage (see table)
- **Description**: Microsoft Bond compact binary protocol.
- **Best For**: .NET services already on Bond.

### MS Bond Fast
- **Type**: Binary (Bond Fast Binary)
- **Status**: ⚠️ Partial data coverage (see table)
- **Description**: Microsoft Bond fast binary protocol — often among top throughput results for simple payloads.
- **Best For**: High-throughput .NET microservices using Bond.

### MS Bond Json
- **Type**: JSON (Bond JSON)
- **Status**: ⚠️ Partial data coverage (see table)
- **Description**: Bond’s JSON protocol variant (human-readable Bond payloads).

---

## JSON Serializers

### JsonNetSerializer (Newtonsoft.Json)
- **Type**: JSON
- **Status**: ✅ All benchmark passed
- **Description**: The most popular .NET JSON library. Extensive feature set including LINQ support.
- **Best For**: General-purpose JSON serialization, complex object graphs, flexible configuration.

### JsonNetHelperSerializer
- **Type**: JSON
- **Status**: ✅ All benchmark passed
- **Description**: Newtonsoft.Json with helper optimizations for common patterns.
- **Best For**: High-performance scenarios with Newtonsoft.

### FastJson
- **Type**: JSON
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: Fast, lightweight JSON serializer focused on speed.
- **Best For**: Simple objects where raw speed is priority.
- **Limitations**: Does not support circular references (ObjectGraph).

### Jil
- **Type**: JSON
- **Status**: ✅ All benchmark passed
- **Description**: High-performance JSON serializer using Sigil for dynamic method generation.
- **Best For**: High-throughput JSON serialization, minimal allocations.
- **Limitations**: Requires public setters, limited customization.

### NetJSON
- **Type**: JSON
- **Status**: ✅ All benchmark passed
- **Description**: Extremely fast JSON serializer with minimal overhead.
- **Best For**: Maximum performance JSON serialization.

### ServiceStackJsonSerializer
- **Type**: JSON
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: Part of ServiceStack framework. Feature-rich with text-based format support.
- **Limitations**: Does not support circular references (ObjectGraph).

### ServiceStackTypeSerializer (`ServiceStack`)
- **Type**: Binary / type serializer (ServiceStack.Text)
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: ServiceStack’s non-JSON type serializer path (`ServiceStack` name in logs).
- **Limitations**: Does not support circular references (ObjectGraph).

### SpanJson
- **Type**: JSON
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: High-performance JSON serializer using Span<T> for zero-allocation parsing.
- **Limitations**: Does not support circular references (ObjectGraph).

### Utf8Json
- **Type**: JSON
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: Fast JSON serializer working directly with UTF-8 bytes.
- **Limitations**: Does not support circular references (ObjectGraph).

---

## Binary Serializers

### ProtoBufSerializer (protobuf-net)
- **Type**: Binary (Protocol Buffers)
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: Popular .NET implementation of Google's Protocol Buffers. Compact binary format.
- **Best For**: Cross-platform communication, microservices, storage efficiency.
- **Limitations**: Cannot handle circular references (ObjectGraph fails).

### GoogleProtobufSerializer
- **Type**: Binary (Official Google)
- **Status**: ⚠️ Registered; limited without full `.proto` / `IMessage` coverage for all fixtures
- **Description**: Official Google Protobuf library for .NET. Requires code generation from .proto files.
- **Limitations**: Requires .proto schema definitions and generated code. Only types implementing IMessage are supported. Use protobuf-net for dynamic scenarios.

### FsPicklerBinarySerializer
- **Type**: Binary
- **Status**: ✅ All benchmark passed
- **Description**: F#-based serializer with excellent support for F# types and general .NET objects.
- **Best For**: F# projects, complex object graphs, functional types.

### FsPicklerJsonSerializer
- **Type**: JSON
- **Status**: ✅ All benchmark passed
- **Description**: JSON variant of FsPickler with same feature set.
- **Best For**: F# projects needing JSON output.

### HyperionSerializer
- **Type**: Binary
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: High-performance binary serializer from the Akka.NET team.
- **Best For**: Akka.NET clusters, distributed systems, actor messaging.
- **Limitations**: Can crash with StackOverflow/SegFault on very deep circular references (ObjectGraph).

### NetSerializer
- **Type**: Binary
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: Fast, compact binary serializer with minimal overhead.
- **Limitations**: Crashes on circular references (ObjectGraph).

### SharpSerializer
- **Type**: Binary/XML
- **Status**: ✅ All benchmark passed
- **Description**: Versatile serializer supporting both binary and XML output. Good for property-level control.
- **Best For**: Applications needing format flexibility, property-level serialization control.

### ApexSerializer
- **Type**: Binary
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: High-performance binary serializer with advanced features.
- **Limitations**: Crashes on circular references (ObjectGraph).

---

## XML Serializers

### ExtendedXmlSerializer
- **Type**: XML
- **Status**: ⚠️ Benchmarked only with Integer
- **Description**: Advanced XML serializer with support for complex scenarios (collections, polymorphism).
- **Best For**: Complex XML scenarios requiring advanced features.
- **Limitations**: Comparison errors on most types; limited to Integer only.

### YAXLibSerializer
- **Type**: XML
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: Flexible XML serializer with attribute-based configuration.
- **Best For**: Human-readable XML with custom formatting.
- **Limitations**: Does not support circular references (ObjectGraph).

---

## YAML Serializers

### YamlDotNetSerializer
- **Type**: YAML
- **Status**: ✅ All benchmark passed
- **Description**: Popular YAML library for .NET. Human-readable format ideal for configuration.
- **Best For**: Configuration files, human-readable data exchange, DevOps scenarios.

### SharpYamlSerializer
- **Type**: YAML
- **Status**: ⚠️ Benchmarked with all except ObjectGraph
- **Description**: Fast YAML serializer with comprehensive spec support.
- **Limitations**: Maximum nesting depth limit of 64 exceeded by ObjectGraph.

---

## Specialized/High-Performance

### CerasSerializer
- **Type**: Binary
- **Status**: ✅ All benchmark passed
- **Description**: High-performance binary serializer with versioning support. Handles circular references automatically.
- **Best For**: Game development, real-time applications requiring versioning, complex object graphs.
- **Limitations**: None significant for benchmark test data.

### MemoryPackSerializer
- **Type**: Binary
- **Status**: ✅ All benchmark passed (Integer, SimpleObject, StringArray)
- **Description**: Ultra-high-performance serializer from the MagicOnion team. Uses [MemoryPackable] attributes with MemoryPack.Generator for build-time code generation.
- **Best For**: gRPC scenarios, maximum throughput with modern C# features.
- **Limitations**: Requires MemoryPack.Generator package for code generation at build time.

### ZeroFormatterSerializer
- **Type**: Binary
- **Status**: ⚠️ Registered; best results with zfc-generated formatters
- **Description**: Fast binary serializer with zero-copy deserialization.
- **Best For**: Game networking, real-time applications.
- **Limitations**: Requires [ZeroFormattable] attribute AND zfc (ZeroFormatter.Compiler) command-line tool to generate formatters at build time. Formatters must be registered at startup.

### FlatSharpSerializer
- **Type**: Binary (FlatBuffers)
- **Status**: ✅ All benchmark passed (Integer, SimpleObject, StringArray)
- **Description**: .NET implementation of Google's FlatBuffers. Zero-copy deserialization using [FlatBufferTable] attributes with virtual properties.
- **Best For**: Game development, embedded systems, zero-copy scenarios.
- **Limitations**: Requires FlatSharp.Compiler package and virtual properties on annotated types.

### BinaryPackSerializer
- **Type**: Binary
- **Status**: ⚠️ Registered; limited type requirements (`T : new()`)
- **Description**: High-performance binary serializer using Memory<T>.
- **Best For**: Modern .NET applications using Memory<T> and Span<T>.
- **Limitations**: Requires compile-time type knowledge with proper generic constraints (T : new()). Cannot work with arbitrary types via reflection.

### GroBufSerializer
- **Type**: Binary
- **Status**: ⚠️ Benchmarked only with Integer, SimpleObject
- **Description**: Fast binary serializer with emphasis on simplicity.
- **Best For**: Simple objects, high-speed scenarios.
- **Limitations**: Comparison errors on complex types; limited to simple types.

### MigrantSerializer
- **Type**: Binary
- **Status**: ⚠️ Benchmarked only with Integer, SimpleObject
- **Description**: Migration-capable serializer with versioning support.
- **Best For**: Long-term data storage requiring schema evolution.
- **Limitations**: BadImageFormatException on complex types; limited to simple types.

### FluentSerializerJson
- **Type**: JSON
- **Status**: ⚠️ Registered; may fail without profile mappings
- **Description**: Fluent API JSON serializer from the FluentSerializer project.
- **Limitations**: Requires profile mappings for each type to be defined at compile time. Cannot work with arbitrary types without profiles.

### CsvHelperSerializer
- **Type**: CSV
- **Status**: ⚠️ Benchmarked only with Integer, SimpleObject
- **Description**: Popular CSV library for .NET.
- **Best For**: Tabular data export/import for simple flat objects.
- **Limitations**: CSV is flat tabular format - cannot handle nested objects, arrays, or circular references. Limited to simple types.

---

## Partially Tested Serializers

All 38 serializers remain **registered** in `Program.cs`. Coverage is limited via `Supports()` / runtime failures for some combinations — failures are recorded in `benchmark-errors.csv`. Historical “permanently disabled” wording was wrong: entries still run; they may skip types or error.

| Serializer | Reason | Typical coverage |
|------------|--------|------------------|
| **Apex.Serialization** | Crashes on circular refs | All except ObjectGraph |
| **BinaryPack** | Compile-time type required (`T : new()`) | Limited fixtures |
| **MS Bond Compact/Fast/Json** | Bond schema / generated types | All except ObjectGraph (typical) |
| **CsvHelper** | CSV is flat; no nested objects | Integer, SimpleObject |
| **ExtendedXmlSerializer** | Comparison / fidelity issues | Often Integer only |
| **FastJson** | Circular reference issues | All except ObjectGraph |
| **FlatSharp** | FlatBuffers-style models | Integer, SimpleObject, StringArray (and more if models allow) |
| **FluentSerializer** | Profile mappings required | Often fails without setup |
| **Google.Protobuf** | `.proto` / `IMessage` required | Limited without generated messages |
| **GroBuf** | Comparison / fidelity issues | Integer, SimpleObject |
| **Hyperion** | StackOverflow on deep circular refs | All except ObjectGraph |
| **JavaScriptSerializer** | Legacy `System.Web` — stubbed on modern .NET (`N/A` name) | Not a meaningful run on .NET 8 |
| **MemoryPack** | Source-generated models | Subset of fixtures with MemoryPack types |
| **Migrant** | Platform / image issues on some hosts | Integer, SimpleObject |
| **NetSerializer** | Crashes on circular refs | All except ObjectGraph |
| **ServiceStack Json** | Circular reference issues | All except ObjectGraph |
| **ServiceStack** (type serializer) | Circular reference issues | All except ObjectGraph |
| **SharpSerializer** | NullReferenceException on some graphs | SimpleObject, StringArray, EDI_835 |
| **SharpYaml** | Max nesting depth exceeded | All except ObjectGraph |
| **SpanJson** | No circular refs | All except ObjectGraph |
| **Utf8Json** | No circular refs | All except ObjectGraph |
| **XmlSerializer** | No circular refs | All except ObjectGraph |
| **YAXLib** | No circular refs | All except ObjectGraph |
| **ZeroFormatter** | Prefers zfc-generated formatters | Limited without build-time formatters |

---

## Serializer Selection Guide

### For Maximum Performance
1. **Jil** - Best for JSON with public setters
2. **NetJSON** - Fastest JSON for simple objects
3. **ProtoBuf** - Best binary size/speed ratio
4. **Hyperion** - Best for distributed systems

### For Flexibility
1. **Newtonsoft.Json** - Most features, widest compatibility
2. **FsPickler** - Best F# support, handles complex graphs
3. **SharpSerializer** - Binary/XML dual support

### For Interoperability
1. **ProtoBuf** - Cross-platform standard
2. **Json.NET** - Industry standard JSON
3. **YamlDotNet** - Human-readable config files

### For Microsoft Stack
1. **DataContractJsonSerializer** - WCF/REST compatibility
2. **XmlSerializer** - SOAP/XML services
3. **BinarySerializer** - Legacy .NET interop

---

*Last Updated: April 2026 - 38 Serializers Benchmarked*
