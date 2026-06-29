# The C# Ecosystem: High-Performance Serialization

In the .NET ecosystem, serialization has evolved dramatically over the past decade. With modern .NET memory primitives (`Span<T>`, `Memory<T>`) and source generators, the landscape shifted from heavy reflection-based engines to lower-allocation, code-generated libraries.

## What this benchmark measures vs the wider ecosystem

This suite registers **38 serializers** in [`c-sharp/src/Program.cs`](../../c-sharp/src/Program.cs). Full inventory: [C# tested serializers](c-sharp_tested_serializers.md).

**Prominent ecosystem libraries not registered here** (discussed for context only):

* **System.Text.Json** — Microsoft’s official high-performance JSON stack (source generators available).
* **MessagePack for C#** — Popular schemaless binary format in gaming and RPC.
* **Wire** — Historical binary serializer (not in this harness).

## The Power of `Span<T>` and `Memory<T>`

Historically, reading a byte array meant copying parts of it into new arrays. Modern serializers can create a window over existing memory without allocating new objects.
Serializers in this suite that lean on modern layouts include **MemoryPack** and **FlatSharp** (among others).

## AOT and Source Generators

Reflection is slow and breaks down in AOT scenarios. Source generators produce hard-coded serialization methods at build time. In this suite, **MemoryPack** is the clearest example of that approach.

## The Garbage Collector (GC) Pressure

In high-throughput .NET applications, a common bottleneck is Garbage Collection from temporary strings or buffers. Choosing a serializer is often as much about allocations as about raw CPU time.

## Prominent serializers *in this suite*

* **MemoryPack** — High-throughput, source-generated binary packing.
* **Protobuf-net** — Protocol Buffers for .NET without requiring Google.Protobuf message types for all scenarios.
* **MS Bond Fast / Compact / Json** — Microsoft Bond protocols (Bond-generated types under `src/Bond/`).
* **Json.NET / Jil / NetJSON / SpanJson / Utf8Json** — JSON options with different performance and feature trade-offs.
* **FlatSharp** — FlatBuffers-style zero-copy access patterns for .NET.

For statuses, limitations, and partial coverage, see [C# tested serializers](c-sharp_tested_serializers.md).
