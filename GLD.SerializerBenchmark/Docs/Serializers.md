# Serializer Reference Guide

Complete reference for all **38 serializers** included in the benchmark suite, organized by category.

## Table of Contents
- [Microsoft Built-in](#microsoft-built-in)
- [JSON Serializers](#json-serializers)
- [Binary Serializers](#binary-serializers)
- [XML Serializers](#xml-serializers)
- [YAML Serializers](#yaml-serializers)
- [Specialized/High-Performance](#specializedhigh-performance)
- [Disabled Serializers](#disabled-serializers)

---

## Microsoft Built-in

### BinarySerializer
- **Type**: Binary
- **Status**: ✅ Working
- **Description**: Microsoft's legacy binary formatter. Simple binary serialization for .NET objects.
- **Limitations**: Limited type support, security concerns with untrusted data.

### DataContractSerializer
- **Type**: XML
- **Status**: ✅ Working
- **Description**: Microsoft's WCF-era serializer. Uses DataContract attributes for explicit schema control.
- **Best For**: WCF services, interop scenarios requiring explicit contracts.

### DataContractJsonSerializer
- **Type**: JSON
- **Status**: ✅ Working
- **Description**: JSON variant of DataContractSerializer. Part of .NET framework.
- **Best For**: WCF REST services, Microsoft stack compatibility.

### XmlSerializer
- **Type**: XML
- **Status**: ⚠️ Disabled (ObjectGraph only)
- **Description**: Classic .NET XML serializer. Requires public parameterless constructors.
- **Best For**: XML-based APIs, SOAP services, configuration files.
- **Limitations**: Does not support circular references (ObjectGraph).

---

## JSON Serializers

### JsonNetSerializer (Newtonsoft.Json)
- **Type**: JSON
- **Status**: ✅ Working
- **Description**: The most popular .NET JSON library. Extensive feature set including LINQ support.
- **Best For**: General-purpose JSON serialization, complex object graphs, flexible configuration.

### JsonNetHelperSerializer
- **Type**: JSON
- **Status**: ✅ Working
- **Description**: Newtonsoft.Json with helper optimizations for common patterns.
- **Best For**: High-performance scenarios with Newtonsoft.

### FastJson
- **Type**: JSON
- **Status**: ⚠️ Disabled (ObjectGraph only)
- **Description**: Fast, lightweight JSON serializer focused on speed.
- **Best For**: Simple objects where raw speed is priority.
- **Limitations**: Does not support circular references (ObjectGraph).

### Jil
- **Type**: JSON
- **Status**: ✅ Working
- **Description**: High-performance JSON serializer using Sigil for dynamic method generation.
- **Best For**: High-throughput JSON serialization, minimal allocations.
- **Limitations**: Requires public setters, limited customization.

### NetJSON
- **Type**: JSON
- **Status**: ✅ Working
- **Description**: Extremely fast JSON serializer with minimal overhead.
- **Best For**: Maximum performance JSON serialization.

### ServiceStackJsonSerializer
- **Type**: JSON
- **Status**: ⚠️ Disabled (ObjectGraph only)
- **Description**: Part of ServiceStack framework. Feature-rich with text-based format support.
- **Limitations**: Does not support circular references (ObjectGraph).

### SpanJson
- **Type**: JSON
- **Status**: ⚠️ Disabled (ObjectGraph only)
- **Description**: High-performance JSON serializer using Span<T> for zero-allocation parsing.
- **Limitations**: Does not support circular references (ObjectGraph).

### Utf8Json
- **Type**: JSON
- **Status**: ⚠️ Disabled (ObjectGraph only)
- **Description**: Fast JSON serializer working directly with UTF-8 bytes.
- **Limitations**: Does not support circular references (ObjectGraph).

---

## Binary Serializers

### ProtoBufSerializer (protobuf-net)
- **Type**: Binary (Protocol Buffers)
- **Status**: ✅ Working (except ObjectGraph)
- **Description**: Popular .NET implementation of Google's Protocol Buffers. Compact binary format.
- **Best For**: Cross-platform communication, microservices, storage efficiency.
- **Limitations**: Cannot handle circular references (ObjectGraph fails).

### GoogleProtobufSerializer
- **Type**: Binary (Official Google)
- **Status**: ❌ Permanently Disabled
- **Description**: Official Google Protobuf library for .NET. Requires code generation from .proto files.
- **Limitations**: Requires .proto schema definitions and generated code. Only types implementing IMessage are supported. Use protobuf-net for dynamic scenarios.

### FsPicklerBinarySerializer
- **Type**: Binary
- **Status**: ✅ Working
- **Description**: F#-based serializer with excellent support for F# types and general .NET objects.
- **Best For**: F# projects, complex object graphs, functional types.

### FsPicklerJsonSerializer
- **Type**: JSON
- **Status**: ✅ Working
- **Description**: JSON variant of FsPickler with same feature set.
- **Best For**: F# projects needing JSON output.

### HyperionSerializer
- **Type**: Binary
- **Status**: ⚠️ Disabled (ObjectGraph only)
- **Description**: High-performance binary serializer from the Akka.NET team.
- **Best For**: Akka.NET clusters, distributed systems, actor messaging.
- **Limitations**: Can crash with StackOverflow/SegFault on very deep circular references (ObjectGraph).

### NetSerializer
- **Type**: Binary
- **Status**: ⚠️ Disabled (ObjectGraph only)
- **Description**: Fast, compact binary serializer with minimal overhead.
- **Limitations**: Crashes on circular references (ObjectGraph).

### SharpSerializer
- **Type**: Binary/XML
- **Status**: ✅ Working
- **Description**: Versatile serializer supporting both binary and XML output. Good for property-level control.
- **Best For**: Applications needing format flexibility, property-level serialization control.

### ApexSerializer
- **Type**: Binary
- **Status**: ⚠️ Disabled (ObjectGraph only)
- **Description**: High-performance binary serializer with advanced features.
- **Limitations**: Crashes on circular references (ObjectGraph).

---

## XML Serializers

### ExtendedXmlSerializer
- **Type**: XML
- **Status**: ⚠️ Disabled (all except Integer)
- **Description**: Advanced XML serializer with support for complex scenarios (collections, polymorphism).
- **Best For**: Complex XML scenarios requiring advanced features.
- **Limitations**: Comparison errors on most types; limited to Integer only.

### YAXLibSerializer
- **Type**: XML
- **Status**: ⚠️ Disabled (ObjectGraph only)
- **Description**: Flexible XML serializer with attribute-based configuration.
- **Best For**: Human-readable XML with custom formatting.
- **Limitations**: Does not support circular references (ObjectGraph).

---

## YAML Serializers

### YamlDotNetSerializer
- **Type**: YAML
- **Status**: ✅ Working
- **Description**: Popular YAML library for .NET. Human-readable format ideal for configuration.
- **Best For**: Configuration files, human-readable data exchange, DevOps scenarios.

### SharpYamlSerializer
- **Type**: YAML
- **Status**: ⚠️ Disabled (ObjectGraph only)
- **Description**: Fast YAML serializer with comprehensive spec support.
- **Limitations**: Maximum nesting depth limit of 64 exceeded by ObjectGraph.

---

## Specialized/High-Performance

### CerasSerializer
- **Type**: Binary
- **Status**: ✅ Working
- **Description**: High-performance binary serializer with versioning support. Handles circular references automatically.
- **Best For**: Game development, real-time applications requiring versioning, complex object graphs.
- **Limitations**: None significant for benchmark test data.

### MemoryPackSerializer
- **Type**: Binary
- **Status**: ✅ Working (Integer, SimpleObject, StringArray)
- **Description**: Ultra-high-performance serializer from the MagicOnion team. Uses annotated types with [MemoryPackable] attribute.
- **Best For**: gRPC scenarios, maximum throughput with modern C# features.
- **Limitations**: Requires compile-time annotated types. Uses parallel type folder (MPack/) like Bond approach.

### ZeroFormatterSerializer
- **Type**: Binary
- **Status**: ❌ Requires Compile-Time Registration
- **Description**: Fast binary serializer with zero-copy deserialization.
- **Best For**: Game networking, real-time applications.
- **Limitations**: Requires [ZeroFormattable] attribute AND compile-time code generation to create formatters. The ZFmt/ folder types have attributes but the formatters weren't generated at build time.

### FlatSharpSerializer
- **Type**: Binary (FlatBuffers)
- **Status**: ❌ Requires Compile-Time Generation
- **Description**: .NET implementation of Google's FlatBuffers. Zero-copy deserialization.
- **Best For**: Game development, embedded systems, zero-copy scenarios.
- **Limitations**: Requires [FlatBufferTable] attribute AND FlatSharp compiler to generate serialization code at build time. The FShrp/ folder types have attributes but the code wasn't generated.

### BinaryPackSerializer
- **Type**: Binary
- **Status**: ❌ Permanently Disabled
- **Description**: High-performance binary serializer using Memory<T>.
- **Best For**: Modern .NET applications using Memory<T> and Span<T>.
- **Limitations**: Requires compile-time type knowledge with proper generic constraints (T : new()). Cannot work with arbitrary types via reflection.

### GroBufSerializer
- **Type**: Binary
- **Status**: ⚠️ Disabled (Integer, SimpleObject only)
- **Description**: Fast binary serializer with emphasis on simplicity.
- **Best For**: Simple objects, high-speed scenarios.
- **Limitations**: Comparison errors on complex types; limited to simple types.

### MigrantSerializer
- **Type**: Binary
- **Status**: ⚠️ Disabled (Integer, SimpleObject only)
- **Description**: Migration-capable serializer with versioning support.
- **Best For**: Long-term data storage requiring schema evolution.
- **Limitations**: BadImageFormatException on complex types; limited to simple types.

### FluentSerializerJson
- **Type**: JSON
- **Status**: ❌ Permanently Disabled
- **Description**: Fluent API JSON serializer from the FluentSerializer project.
- **Limitations**: Requires profile mappings for each type to be defined at compile time. Cannot work with arbitrary types without profiles.

### CsvHelperSerializer
- **Type**: CSV
- **Status**: ⚠️ Disabled (Integer, SimpleObject only)
- **Description**: Popular CSV library for .NET.
- **Best For**: Tabular data export/import for simple flat objects.
- **Limitations**: CSV is flat tabular format - cannot handle nested objects, arrays, or circular references. Limited to simple types.

---

## Disabled Serializers

The following serializers are disabled in the benchmark via the `Supports()` method:

| Serializer | Reason | Supported Data |
|------------|--------|----------------|
| **Apex.Serialization** | Crashes on circular refs | All except ObjectGraph |
| **BinaryPack** | Compile-time type required (T : new()) | ❌ Permanently Disabled |
| **Bond Compact/Fast/Json** | Schema attributes required | All except ObjectGraph |
| **Ceras** | ✅ Now Working | All test data |
| **CsvHelper** | CSV is flat format, no nested objects | Integer, SimpleObject |
| **ExtendedXmlSerializer** | Comparison errors | Integer only |
| **FastJson** | Circular reference issues | All except ObjectGraph |
| **FlatSharp** | [FlatBufferTable] + compiler | ❌ Build-time code gen needed |
| **FluentSerializer** | Profile mappings required | ❌ Permanently Disabled |
| **Google.Protobuf** | .proto definitions required | ❌ Permanently Disabled |
| **GroBuf** | Comparison errors | Integer, SimpleObject |
| **Hyperion** | StackOverflow on deep circular refs | All except ObjectGraph |
| **JavaScriptSerializer** | System.Web not in .NET Core | ❌ Permanently Disabled |
| **MemoryPack** | ✅ Now Working | Integer, SimpleObject, StringArray |
| **Migrant** | BadImageFormatException | Integer, SimpleObject |
| **NetSerializer** | Crashes on circular refs | All except ObjectGraph |
| **ServiceStack Json** | Circular reference issues | All except ObjectGraph |
| **ServiceStack Type** | Circular reference issues | All except ObjectGraph |
| **SharpSerializer** | NullReferenceException | SimpleObject, StringArray, EDI_835 |
| **SharpYaml** | Max nesting depth exceeded | All except ObjectGraph |
| **SpanJson** | Does not support circular refs | All except ObjectGraph |
| **Utf8Json** | Does not support circular refs | All except ObjectGraph |
| **XmlSerializer** | Does not support circular refs | All except ObjectGraph |
| **YAXLib** | Does not support circular refs | All except ObjectGraph |
| **ZeroFormatter** | [ZeroFormattable] + code generation | ❌ Build-time formatters needed |

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
