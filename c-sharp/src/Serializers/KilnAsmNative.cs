using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using Newtonsoft.Json.Linq;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Tier 2A managed FFI bindings for shared libkiln_asm_bench.so (gld-kiln-asm 0.2.0)
    /// using .NET source-generated [LibraryImport] + [SuppressGCTransition].
    /// </summary>
    internal static unsafe partial class KilnAsmNative
    {
        public const string LibName = "kiln_asm_bench";
        public const string Version = "0.2.0";

        public const int KILN_OK = 0;
        public const uint KILN_OPT_EMBEDDED = 1u << 3;
        public const ushort KILN_DTYPE_F64 = 1;
        public const ushort KILN_DTYPE_F32 = 2;
        public const ushort KILN_DTYPE_I64 = 14;
        public const ulong KILN_LARGE_CAP = 1UL << 28;

        static readonly object ResolverLock = new();
        static bool _initialized;

        static KilnAsmNative()
        {
            EnsureInitialized();
        }

        public static void EnsureInitialized()
        {
            if (_initialized) return;
            lock (ResolverLock)
            {
                if (_initialized) return;
                VerifyStructSizes();
                NativeLibrary.SetDllImportResolver(typeof(KilnAsmNative).Assembly, ResolveLibrary);
                _initialized = true;
            }
        }

        static IntPtr ResolveLibrary(string libraryName, Assembly assembly, DllImportSearchPath? searchPath)
        {
            if (!string.Equals(libraryName, LibName, StringComparison.Ordinal))
                return IntPtr.Zero;

            var envPath = Environment.GetEnvironmentVariable("KILN_ASM_LIB");
            if (!string.IsNullOrEmpty(envPath) && File.Exists(envPath))
                return NativeLibrary.Load(envPath);

            foreach (var start in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
            {
                if (string.IsNullOrEmpty(start)) continue;
                var dir = Path.GetFullPath(start);
                for (var i = 0; i < 10; i++)
                {
                    var cand = Path.Combine(dir, "build", "kiln-asm", "libkiln_asm_bench.so");
                    if (File.Exists(cand))
                        return NativeLibrary.Load(cand);
                    var parent = Directory.GetParent(dir);
                    if (parent == null) break;
                    dir = parent.FullName;
                }
            }

            return NativeLibrary.TryLoad("libkiln_asm_bench.so", assembly, searchPath, out var handle)
                ? handle
                : IntPtr.Zero;
        }

        static void VerifyStructSizes()
        {
            AssertSize<KilnArena>(24);
            AssertSize<KilnReadOpts>(24);
            AssertSize<KilnResult>(16);
            AssertSize<KilnStr>(16);
            AssertSize<KilnList>(16);
            AssertSize<KilnTensor>(144);
            AssertSize<KilnTensorDir>(32);
            AssertSize<KilnIdTensors>(40);
            AssertSize<BenchMessage>(64);
            AssertSize<BenchDocumentMeta>(24);
            AssertSize<BenchDocumentItem>(32);
            AssertSize<BenchDocument>(64);
            AssertSize<BenchTelemetry>(56);
            AssertSize<BenchStrings>(16);
            AssertSize<BenchEventAttr>(32);
            AssertSize<BenchEvent>(72);
            AssertSize<BenchTableColumns>(352);
            AssertSize<BenchTableProject>(16);
            AssertSize<BenchSignalLeg>(16);
            AssertSize<BenchSignal>(80);
            AssertSize<BenchRequest>(64);
        }

        static void AssertSize<T>(int expect) where T : unmanaged
        {
            if (sizeof(T) != expect)
                throw new InvalidOperationException($"gld-kiln-asm ABI mismatch: sizeof({typeof(T).Name})={sizeof(T)} != {expect}");
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KilnArena
        {
            public byte* Base;
            public byte* Cur;
            public byte* End;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KilnReadOpts
        {
            public ulong MaxCount;
            public ulong MaxBytes;
            public uint MaxDepth;
            public uint Flags;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KilnResult
        {
            public ulong Bytes;
            public ulong Hash;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KilnStr
        {
            public byte* Ptr;
            public ulong Len;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KilnList
        {
            public void* Items;
            public ulong Count;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchMessage
        {
            public byte FBool;
            public int FInt32;
            public long FInt64;
            public double FFloat64;
            public KilnStr FString;
            public byte FBool2;
            public int FInt322;
            public KilnStr FString2;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchDocumentMeta
        {
            public KilnStr Region;
            public int Version;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchDocumentItem
        {
            public KilnStr Sku;
            public int Qty;
            public long PriceMinor;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchDocument
        {
            public KilnStr Id;
            public int Status;
            public BenchDocumentMeta Meta;
            public KilnList Items;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchTelemetry
        {
            public KilnStr Source;
            public long Ts;
            public KilnList Tags;
            public KilnList Values;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchStrings
        {
            public KilnList Items;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchEventAttr
        {
            public KilnStr Key;
            public KilnStr Value;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchEvent
        {
            public KilnStr EventId;
            public KilnStr EventType;
            public long OccurredAt;
            public KilnStr Producer;
            public KilnList Attrs;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchTableColumns
        {
            public KilnList FFloat0, FFloat1, FFloat2, FFloat3;
            public KilnList FFloat4, FFloat5, FFloat6, FFloat7;
            public KilnList FFloat8, FFloat9, FFloat10, FFloat11;
            public KilnList FFloat12, FFloat13, FFloat14, FFloat15;
            public KilnList FInt0, FInt1, FInt2, FInt3;
            public KilnList FStr0, FStr1;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchTableProject
        {
            public KilnList FFloat0;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchSignalLeg
        {
            public long LegId;
            public int LegQty;
            public int LegPad;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchSignal
        {
            public long Seq;
            public long Ts;
            public long PriceMantissa;
            public int Qty;
            public int Flags;
            public KilnStr Symbol;
            public KilnStr Venue;
            public KilnList Legs;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KilnTensor
        {
            public byte* Name;
            public ulong NameLen;
            public byte* Layout;
            public ulong LayoutLen;
            public byte* Data;
            public ulong DataLen;
            public fixed ulong Shape[8];
            public ushort Dtype;
            public byte Rank;
            public byte Pad0;
            public ushort QuantScheme;
            public ushort QuantAxis;
            public uint GroupSize;
            public uint ScaleIndex;
            public uint OuterIndex;
            public uint BlockSize;
            public ulong ElemCount;

            [MethodImpl(MethodImplOptions.AggressiveInlining)]
            public static void Init(KilnTensor* t)
            {
                *t = default;
                t->QuantAxis = 0xFFFF;
                t->ScaleIndex = 0xFFFFFFFF;
                t->OuterIndex = 0xFFFFFFFF;
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KilnTensorDir
        {
            public KilnTensor* Items;
            public ulong Count;
            public ulong BlockLength;
            public uint Flags;
            public uint Version;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KilnIdTensors
        {
            public long Id;
            public KilnTensorDir Batch;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct BenchRequest
        {
            public long RequestId;
            public KilnStr Model;
            public float Temperature;
            public KilnTensorDir Inputs;
        }

        // ---- Suite codecs ----
        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_message")]
        [SuppressGCTransition]
        public static partial int EncodeMessage(BenchMessage* input, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_message")]
        [SuppressGCTransition]
        public static partial int DecodeMessage(byte* src, nuint len, BenchMessage* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_message_batch")]
        [SuppressGCTransition]
        public static partial int EncodeMessageBatch(BenchMessage* items, nuint count, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_message_batch")]
        [SuppressGCTransition]
        public static partial int DecodeMessageBatch(byte* src, nuint len, BenchMessage** outItems, nuint* outCount, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_document")]
        [SuppressGCTransition]
        public static partial int EncodeDocument(BenchDocument* input, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_document")]
        [SuppressGCTransition]
        public static partial int DecodeDocument(byte* src, nuint len, BenchDocument* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_document_batch")]
        [SuppressGCTransition]
        public static partial int EncodeDocumentBatch(BenchDocument* items, nuint count, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_document_batch")]
        [SuppressGCTransition]
        public static partial int DecodeDocumentBatch(byte* src, nuint len, BenchDocument** outItems, nuint* outCount, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_telemetry")]
        [SuppressGCTransition]
        public static partial int EncodeTelemetry(BenchTelemetry* input, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_telemetry")]
        [SuppressGCTransition]
        public static partial int DecodeTelemetry(byte* src, nuint len, BenchTelemetry* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_telemetry_batch")]
        [SuppressGCTransition]
        public static partial int EncodeTelemetryBatch(BenchTelemetry* items, nuint count, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_telemetry_batch")]
        [SuppressGCTransition]
        public static partial int DecodeTelemetryBatch(byte* src, nuint len, BenchTelemetry** outItems, nuint* outCount, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_strings")]
        [SuppressGCTransition]
        public static partial int EncodeStrings(BenchStrings* input, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_strings")]
        [SuppressGCTransition]
        public static partial int DecodeStrings(byte* src, nuint len, BenchStrings* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_strings_batch")]
        [SuppressGCTransition]
        public static partial int EncodeStringsBatch(BenchStrings* items, nuint count, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_strings_batch")]
        [SuppressGCTransition]
        public static partial int DecodeStringsBatch(byte* src, nuint len, BenchStrings** outItems, nuint* outCount, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_event")]
        [SuppressGCTransition]
        public static partial int EncodeEvent(BenchEvent* input, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_event")]
        [SuppressGCTransition]
        public static partial int DecodeEvent(byte* src, nuint len, BenchEvent* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_event_batch")]
        [SuppressGCTransition]
        public static partial int EncodeEventBatch(BenchEvent* items, nuint count, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_event_batch")]
        [SuppressGCTransition]
        public static partial int DecodeEventBatch(byte* src, nuint len, BenchEvent** outItems, nuint* outCount, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        // ---- Columnar codecs ----
        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_table_columns")]
        [SuppressGCTransition]
        public static partial int EncodeTableColumns(BenchTableColumns* input, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_table_columns")]
        [SuppressGCTransition]
        public static partial int DecodeTableColumns(byte* src, nuint len, BenchTableColumns* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_table_project")]
        [SuppressGCTransition]
        public static partial int DecodeTableProject(byte* src, nuint len, BenchTableProject* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_nested_row")]
        [SuppressGCTransition]
        public static partial int EncodeNestedRow(BenchDocument* input, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_nested_row")]
        [SuppressGCTransition]
        public static partial int DecodeNestedRow(byte* src, nuint len, BenchDocument* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_nested_row_batch")]
        [SuppressGCTransition]
        public static partial int EncodeNestedRowBatch(BenchDocument* items, nuint count, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_nested_row_batch")]
        [SuppressGCTransition]
        public static partial int DecodeNestedRowBatch(byte* src, nuint len, BenchDocument** outItems, nuint* outCount, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_signal")]
        [SuppressGCTransition]
        public static partial int EncodeSignal(BenchSignal* input, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_signal")]
        [SuppressGCTransition]
        public static partial int DecodeSignal(byte* src, nuint len, BenchSignal* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_signal_batch")]
        [SuppressGCTransition]
        public static partial int EncodeSignalBatch(BenchSignal* items, nuint count, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_signal_batch")]
        [SuppressGCTransition]
        public static partial int DecodeSignalBatch(byte* src, nuint len, BenchSignal** outItems, nuint* outCount, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        // ---- Tensor / KLNT v2 & compliance codecs ----
        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_tensors")]
        [SuppressGCTransition]
        public static partial int EncodeTensors(KilnTensorDir* input, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_tensors")]
        [SuppressGCTransition]
        public static partial int DecodeTensors(byte* src, nuint len, KilnTensorDir* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_encode_bench_request")]
        [SuppressGCTransition]
        public static partial int EncodeRequest(BenchRequest* input, byte* dst, nuint cap, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_bench_request")]
        [SuppressGCTransition]
        public static partial int DecodeRequest(byte* src, nuint len, BenchRequest* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_id_tensors")]
        [SuppressGCTransition]
        public static partial int DecodeIdTensors(byte* src, nuint len, KilnIdTensors* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_id_tensors_framed")]
        [SuppressGCTransition]
        public static partial int DecodeIdTensorsFramed(byte* src, nuint len, KilnIdTensors* output, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_list_f32")]
        [SuppressGCTransition]
        public static partial int DecodeListF32(byte* src, nuint len, byte** rawOut, nuint* countOut, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_list_str")]
        [SuppressGCTransition]
        public static partial int DecodeListStr(byte* src, nuint len, KilnStr** itemsOut, nuint* countOut, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        [LibraryImport(LibName, EntryPoint = "kiln_asm_decode_list_i64_struct")]
        [SuppressGCTransition]
        public static partial int DecodeListI64Struct(byte* src, nuint len, byte** rawOut, nuint* countOut, KilnArena* arena, KilnReadOpts* opts, KilnResult* res);

        // ---- Compliance probe (with exact decoded value reconstruction) ----
        static object DtypeToJson(ushort dtype) => dtype switch
        {
            1 => "f64",
            2 => "f32",
            3 => "f16",
            4 => "bf16",
            5 => "f8e4m3",
            6 => "f8e5m2",
            7 => "bool",
            8 => "i8",
            9 => "u8",
            10 => "i16",
            11 => "u16",
            12 => "i32",
            13 => "u32",
            14 => "i64",
            15 => "u64",
            16 => "i4",
            17 => "u4",
            18 => "e2m1",
            19 => "e8m0",
            _ => (int)dtype,
        };

        static Dictionary<string, object> TensorDirToJson(KilnTensorDir* dir)
        {
            var flags = new List<string>();
            if ((dir->Flags & 1u) != 0) flags.Add("names");
            if ((dir->Flags & 2u) != 0) flags.Add("le");

            var tensors = new List<Dictionary<string, object>>((int)dir->Count);
            for (ulong i = 0; i < dir->Count; i++)
            {
                var t = &dir->Items[i];
                string name = t->Name != null && t->NameLen > 0
                    ? Encoding.UTF8.GetString(t->Name, checked((int)t->NameLen))
                    : null;
                var shape = new List<ulong>(t->Rank);
                for (var r = 0; r < t->Rank; r++)
                    shape.Add(t->Shape[r]);
                var hex = t->DataLen > 0 && t->Data != null
                    ? Convert.ToHexString(new ReadOnlySpan<byte>(t->Data, checked((int)t->DataLen))).ToLowerInvariant()
                    : "";
                tensors.Add(new Dictionary<string, object>
                {
                    ["name"] = name,
                    ["dtype"] = DtypeToJson(t->Dtype),
                    ["shape"] = shape,
                    ["quant_scheme"] = (int)t->QuantScheme,
                    ["data_hex"] = hex,
                });
            }

            return new Dictionary<string, object>
            {
                ["version"] = (int)dir->Version,
                ["flags"] = flags,
                ["tensors"] = tensors,
                ["block_length"] = dir->BlockLength,
            };
        }

        public static object DecodeCompliance(byte[] data, string schemaText)
        {
            EnsureInitialized();
            data ??= Array.Empty<byte>();
            var arenaBuf = (byte*)NativeMemory.Alloc(1 << 20);
            try
            {
                KilnArena arena = new() { Base = arenaBuf, Cur = arenaBuf, End = arenaBuf + (1 << 20) };
                KilnResult res = default;

                fixed (byte* p = data)
                {
                    var ptr = data.Length == 0 ? (byte*)0 : p;
                    var len = (nuint)data.Length;

                    if (string.Equals(schemaText, "tensor-v2", StringComparison.Ordinal))
                    {
                        KilnTensorDir dir = default;
                        var err = DecodeTensors(ptr, len, &dir, &arena, null, &res);
                        if (err != KILN_OK) throw new InvalidDataException($"kiln_asm error {err}");
                        return TensorDirToJson(&dir);
                    }
                    if (string.Equals(schemaText, "frame", StringComparison.Ordinal))
                    {
                        KilnIdTensors v = default;
                        var err = DecodeIdTensorsFramed(ptr, len, &v, &arena, null, &res);
                        if (err != KILN_OK) throw new InvalidDataException($"kiln_asm error {err}");
                        return new Dictionary<string, object>
                        {
                            ["hash"] = res.Hash,
                            ["id"] = v.Id,
                            ["batch"] = TensorDirToJson(&v.Batch),
                        };
                    }
                    if (!string.IsNullOrEmpty(schemaText) && schemaText.StartsWith('{'))
                    {
                        var obj = JObject.Parse(schemaText);
                        var ty = (string)obj["type"];
                        if (ty == "struct")
                        {
                            KilnIdTensors v = default;
                            var err = DecodeIdTensors(ptr, len, &v, &arena, null, &res);
                            if (err != KILN_OK) throw new InvalidDataException($"kiln_asm error {err}");
                            return new Dictionary<string, object>
                            {
                                ["id"] = v.Id,
                                ["batch"] = TensorDirToJson(&v.Batch),
                            };
                        }
                        if (ty == "list")
                        {
                            var elem = (string)obj["element"];
                            if (elem == "f32")
                            {
                                byte* raw = null;
                                nuint cnt = 0;
                                var err = DecodeListF32(ptr, len, &raw, &cnt, &arena, null, &res);
                                if (err != KILN_OK) throw new InvalidDataException($"kiln_asm error {err}");
                                var list = new List<double>((int)cnt);
                                for (nuint i = 0; i < cnt; i++)
                                    list.Add(Unsafe.ReadUnaligned<float>(raw + (i * 4)));
                                return list;
                            }
                            if (elem == "str")
                            {
                                KilnStr* items = null;
                                nuint cnt = 0;
                                var err = DecodeListStr(ptr, len, &items, &cnt, &arena, null, &res);
                                if (err != KILN_OK) throw new InvalidDataException($"kiln_asm error {err}");
                                var list = new List<string>((int)cnt);
                                for (nuint i = 0; i < cnt; i++)
                                    list.Add(items[i].Len == 0 ? "" : Encoding.UTF8.GetString(items[i].Ptr, checked((int)items[i].Len)));
                                return list;
                            }
                            if (elem == "struct{a:i64}")
                            {
                                byte* raw = null;
                                nuint cnt = 0;
                                var err = DecodeListI64Struct(ptr, len, &raw, &cnt, &arena, null, &res);
                                if (err != KILN_OK) throw new InvalidDataException($"kiln_asm error {err}");
                                var list = new List<Dictionary<string, object>>((int)cnt);
                                for (nuint i = 0; i < cnt; i++)
                                    list.Add(new Dictionary<string, object> { ["a"] = Unsafe.ReadUnaligned<long>(raw + (i * 8)) });
                                return list;
                            }
                        }
                    }
                    throw new InvalidDataException($"unsupported kiln schema: {schemaText}");
                }
            }
            finally
            {
                NativeMemory.Free(arenaBuf);
            }
        }
    }
}
