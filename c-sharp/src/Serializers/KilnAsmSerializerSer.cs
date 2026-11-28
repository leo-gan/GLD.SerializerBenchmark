using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using GLD.SerializerBenchmark.TestData.V2;
using static GLD.SerializerBenchmark.Serializers.KilnAsmNative;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// gld-kiln-asm 0.2.0: pure x86-64 Assembly Kiln Wire Format v2 codec via
    /// [LibraryImport] + [SuppressGCTransition] into shared libkiln_asm_bench.so.
    /// Covers all 4 supported Data Sets: suite, columnar, array, and tensor.
    /// Full RFC 3629 UTF-8 validation is always active (no KILN_OPT_TRUSTED).
    /// </summary>
    internal sealed unsafe class KilnAsmSerializerSer : SerDeser, IDisposable
    {
        byte* _outBuf;
        nuint _outCap;
        byte* _arenaBuf;
        nuint _arenaCap;
        byte* _strBuf;
        nuint _strCap;
        nuint _strPos;
        byte* _structBuf;
        nuint _structCap;

        string _fixture;
        bool _batch;
        bool _window;
        int _nx, _ny, _x0, _y0, _wx, _wy;

        public KilnAsmSerializerSer()
        {
            EnsureInitialized();
        }

        ~KilnAsmSerializerSer() => ReleaseUnmanaged();

        public void Dispose()
        {
            ReleaseUnmanaged();
            GC.SuppressFinalize(this);
        }

        void ReleaseUnmanaged()
        {
            if (_outBuf != null) { NativeMemory.Free(_outBuf); _outBuf = null; _outCap = 0; }
            if (_arenaBuf != null) { NativeMemory.Free(_arenaBuf); _arenaBuf = null; _arenaCap = 0; }
            if (_strBuf != null) { NativeMemory.Free(_strBuf); _strBuf = null; _strCap = 0; }
            if (_structBuf != null) { NativeMemory.Free(_structBuf); _structBuf = null; _structCap = 0; }
        }

        public override string Name => "gld-kiln-asm";

        public override string Version => KilnAsmNative.Version;

        public override string StreamMode => "adapted";

        public override bool Supports(string testDataName) =>
            testDataName is "message" or "document" or "telemetry" or "strings" or "event"
                or "table" or "table_project" or "nested_table" or "signal"
                or "grid" or "grid_window"
                or "tensor" or "tensor_view" or "prompt" or "shard" or "request";

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _fixture = ResolveFixture(FixtureName, serializablePrimaryType);
            _batch = serializablePrimaryType != null && serializablePrimaryType.Name.StartsWith("Batch", StringComparison.Ordinal);
            _window = string.Equals(_fixture, "grid_window", StringComparison.Ordinal);
        }

        public override void PrepareData(object data)
        {
            if (data is Grid g)
            {
                _nx = g.Nx;
                _ny = g.Ny;
                _x0 = g.X0;
                _y0 = g.Y0;
                _wx = g.Wx;
                _wy = g.Wy;
            }
            EnsureOut(64 * 1024);
            EnsureArena(256 * 1024);
            EnsureStr(64 * 1024);
            EnsureStruct(64 * 1024);
        }

        public override byte[] SerializeBytes(object serializable)
        {
            var len = EncodeToOutBuf(serializable);
            var arr = new byte[len];
            if (len > 0)
            {
                fixed (byte* dst = arr)
                    Buffer.MemoryCopy(_outBuf, dst, len, len);
            }
            return arr;
        }

        public override object DeserializeBytes(byte[] serialized) =>
            DecodeFromMemory(new ReadOnlyMemory<byte>(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            var len = EncodeToOutBuf(serializable);
            if (len > 0)
                outputStream.Write(new ReadOnlySpan<byte>(_outBuf, len));
        }

        public override object Deserialize(Stream inputStream)
        {
            if (inputStream.CanSeek)
                inputStream.Position = 0;
            if (inputStream is MemoryStream owned && owned.TryGetBuffer(out var seg))
                return DecodeFromMemory(seg.AsMemory(0, checked((int)owned.Length)));
            using var copy = new MemoryStream();
            inputStream.CopyTo(copy);
            return DecodeFromMemory(copy.GetBuffer().AsMemory(0, checked((int)copy.Length)));
        }

        static string ResolveFixture(string fixtureName, Type t)
        {
            if (!string.IsNullOrEmpty(fixtureName))
                return fixtureName;
            if (t == null) return "";
            return t.Name switch
            {
                "Message" or "BatchMessage" => "message",
                "Document" or "BatchDocument" => "document",
                "Telemetry" or "BatchTelemetry" => "telemetry",
                "Strings" or "BatchStrings" => "strings",
                "Event" or "BatchEvent" => "event",
                "TableRow" or "BatchTable" => "table",
                "NestedRow" or "BatchNestedRow" => "nested_table",
                "Signal" or "BatchSignal" => "signal",
                "Grid" => "grid",
                "TensorMatrix" => "tensor",
                "Prompt" => "prompt",
                "Shard" => "shard",
                "InferenceRequest" => "request",
                _ => "",
            };
        }

        static void EnsureUnmanaged(ref byte* ptr, ref nuint cap, nuint need)
        {
            if (need < 4096) need = 4096;
            if (cap >= need) return;
            var next = cap == 0 ? need : Math.Max(need, cap * 2);
            var p = (byte*)NativeMemory.Realloc(ptr, next);
            ptr = p;
            cap = next;
        }

        void EnsureOut(nuint need) => EnsureUnmanaged(ref _outBuf, ref _outCap, need);
        void EnsureArena(nuint need) => EnsureUnmanaged(ref _arenaBuf, ref _arenaCap, need);
        void EnsureStr(nuint need) => EnsureUnmanaged(ref _strBuf, ref _strCap, need);
        void EnsureStruct(nuint need) => EnsureUnmanaged(ref _structBuf, ref _structCap, need);

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        static nuint Align16(nuint n) => (n + 15u) & ~(nuint)15u;

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        KilnStr PushUtf8(string s)
        {
            if (string.IsNullOrEmpty(s))
                return default;
            var maxBytes = (nuint)Encoding.UTF8.GetMaxByteCount(s.Length);
            if (_strPos + maxBytes > _strCap)
                throw new InvalidOperationException("gld-kiln-asm str scratch overflow");
            var dest = new Span<byte>(_strBuf + _strPos, (int)maxBytes);
            var written = Encoding.UTF8.GetBytes(s.AsSpan(), dest);
            var ks = new KilnStr { Ptr = _strBuf + _strPos, Len = (ulong)written };
            _strPos += (nuint)written;
            return ks;
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        static string ReadUtf8(KilnStr ks) =>
            ks.Len == 0 ? "" : Encoding.UTF8.GetString(ks.Ptr, checked((int)ks.Len));

        static int StrMaxBytes(string s) =>
            string.IsNullOrEmpty(s) ? 0 : Encoding.UTF8.GetMaxByteCount(s.Length);

        static void CheckOk(int err, string op)
        {
            if (err != KILN_OK)
                throw new InvalidOperationException($"gld-kiln-asm {op} failed with error {err}");
        }

        KilnArena ResetArena(nuint need)
        {
            EnsureArena(need);
            return new KilnArena { Base = _arenaBuf, Cur = _arenaBuf, End = _arenaBuf + _arenaCap };
        }

        // ==================== ENCODE ====================

        int EncodeToOutBuf(object data)
        {
            _strPos = 0;
            KilnResult res = default;
            KilnReadOpts largeOpts = new() { MaxCount = KILN_LARGE_CAP, MaxBytes = KILN_LARGE_CAP };

            switch (_fixture)
            {
                case "message":
                {
                    if (_batch)
                    {
                        var items = ((BatchMessage)data).Items;
                        var n = items.Count;
                        nuint strNeed = 64;
                        for (var i = 0; i < n; i++)
                            strNeed += (nuint)(StrMaxBytes(items[i].FString) + StrMaxBytes(items[i].FString2));
                        EnsureStr(strNeed);
                        EnsureStruct((nuint)(n * sizeof(BenchMessage) + 64));
                        EnsureOut(strNeed + (nuint)(n * 48 + 64));
                        var arr = (BenchMessage*)_structBuf;
                        for (var i = 0; i < n; i++)
                            FillMessage(items[i], &arr[i]);
                        CheckOk(EncodeMessageBatch(arr, (nuint)n, _outBuf, _outCap, null, &res), "encode message batch");
                    }
                    else
                    {
                        var m = (Message)data;
                        var strNeed = (nuint)(StrMaxBytes(m.FString) + StrMaxBytes(m.FString2) + 16);
                        EnsureStr(strNeed);
                        EnsureOut(strNeed + 64);
                        BenchMessage bm = default;
                        FillMessage(m, &bm);
                        CheckOk(EncodeMessage(&bm, _outBuf, _outCap, null, &res), "encode message");
                    }
                    return checked((int)res.Bytes);
                }

                case "document":
                {
                    if (_batch)
                    {
                        var items = ((BatchDocument)data).Items;
                        var n = items.Count;
                        nuint strNeed = 64;
                        var totalChildren = 0;
                        for (var i = 0; i < n; i++)
                        {
                            var d = items[i];
                            strNeed += (nuint)(StrMaxBytes(d.Id) + StrMaxBytes(d.Meta?.Region));
                            var ch = d.Items;
                            if (ch != null)
                            {
                                totalChildren += ch.Count;
                                for (var j = 0; j < ch.Count; j++)
                                    strNeed += (nuint)StrMaxBytes(ch[j].Sku);
                            }
                        }
                        EnsureStr(strNeed);
                        var headBytes = Align16((nuint)(n * sizeof(BenchDocument)));
                        EnsureStruct(headBytes + (nuint)((totalChildren + 1) * sizeof(BenchDocumentItem)));
                        EnsureOut(strNeed + (nuint)(n * 48 + totalChildren * 24 + 64));
                        var arr = (BenchDocument*)_structBuf;
                        var pool = (BenchDocumentItem*)(_structBuf + headBytes);
                        for (var i = 0; i < n; i++)
                            pool = FillDocument(items[i], &arr[i], pool);
                        CheckOk(EncodeDocumentBatch(arr, (nuint)n, _outBuf, _outCap, null, &res), "encode document batch");
                    }
                    else
                    {
                        var d = (Document)data;
                        nuint strNeed = (nuint)(StrMaxBytes(d.Id) + StrMaxBytes(d.Meta?.Region) + 16);
                        var ch = d.Items;
                        var m = ch?.Count ?? 0;
                        for (var j = 0; j < m; j++) strNeed += (nuint)StrMaxBytes(ch[j].Sku);
                        EnsureStr(strNeed);
                        EnsureStruct((nuint)((m + 1) * sizeof(BenchDocumentItem)));
                        EnsureOut(strNeed + (nuint)(m * 24 + 64));
                        BenchDocument bd = default;
                        FillDocument(d, &bd, (BenchDocumentItem*)_structBuf);
                        CheckOk(EncodeDocument(&bd, _outBuf, _outCap, null, &res), "encode document");
                    }
                    return checked((int)res.Bytes);
                }

                case "telemetry":
                {
                    if (_batch)
                    {
                        var items = ((BatchTelemetry)data).Items;
                        var n = items.Count;
                        nuint strNeed = 64;
                        var totalTags = 0;
                        var totalVals = 0;
                        for (var i = 0; i < n; i++)
                        {
                            var t = items[i];
                            strNeed += (nuint)StrMaxBytes(t.Source);
                            if (t.Tags != null)
                            {
                                totalTags += t.Tags.Count;
                                for (var j = 0; j < t.Tags.Count; j++)
                                    strNeed += (nuint)StrMaxBytes(t.Tags[j]);
                            }
                            if (t.Values != null) totalVals += t.Values.Count;
                        }
                        EnsureStr(strNeed);
                        var headBytes = Align16((nuint)(n * sizeof(BenchTelemetry)));
                        var tagBytes = Align16((nuint)((totalTags + 1) * sizeof(KilnStr)));
                        EnsureStruct(headBytes + tagBytes + (nuint)((totalVals + 1) * sizeof(double)));
                        EnsureOut(strNeed + (nuint)(n * 32 + totalTags * 8 + totalVals * 8 + 64));
                        var arr = (BenchTelemetry*)_structBuf;
                        var tpool = (KilnStr*)(_structBuf + headBytes);
                        var vpool = (double*)(_structBuf + headBytes + tagBytes);
                        for (var i = 0; i < n; i++)
                        {
                            var t = items[i];
                            arr[i].Source = PushUtf8(t.Source);
                            arr[i].Ts = t.Ts;
                            var nt = t.Tags?.Count ?? 0;
                            arr[i].Tags.Count = (ulong)nt;
                            arr[i].Tags.Items = nt > 0 ? tpool : null;
                            for (var j = 0; j < nt; j++) tpool[j] = PushUtf8(t.Tags[j]);
                            tpool += nt;
                            var vspan = CollectionsMarshal.AsSpan(t.Values);
                            var nv = vspan.Length;
                            arr[i].Values.Count = (ulong)nv;
                            arr[i].Values.Items = nv > 0 ? vpool : null;
                            if (nv > 0)
                            {
                                fixed (double* src = vspan)
                                    Buffer.MemoryCopy(src, vpool, nv * 8L, nv * 8L);
                                vpool += nv;
                            }
                        }
                        CheckOk(EncodeTelemetryBatch(arr, (nuint)n, _outBuf, _outCap, null, &res), "encode telemetry batch");
                    }
                    else
                    {
                        var t = (Telemetry)data;
                        nuint strNeed = (nuint)(StrMaxBytes(t.Source) + 16);
                        var nt = t.Tags?.Count ?? 0;
                        for (var j = 0; j < nt; j++) strNeed += (nuint)StrMaxBytes(t.Tags[j]);
                        var vspan = CollectionsMarshal.AsSpan(t.Values);
                        var nv = vspan.Length;
                        EnsureStr(strNeed);
                        EnsureStruct((nuint)((nt + 1) * sizeof(KilnStr)));
                        EnsureOut(strNeed + (nuint)(nt * 8 + nv * 8 + 64));
                        var tpool = (KilnStr*)_structBuf;
                        for (var j = 0; j < nt; j++) tpool[j] = PushUtf8(t.Tags[j]);
                        fixed (double* vp = vspan)
                        {
                            BenchTelemetry bt = new()
                            {
                                Source = PushUtf8(t.Source),
                                Ts = t.Ts,
                                Tags = new KilnList { Items = nt > 0 ? tpool : null, Count = (ulong)nt },
                                Values = new KilnList { Items = nv > 0 ? vp : null, Count = (ulong)nv },
                            };
                            CheckOk(EncodeTelemetry(&bt, _outBuf, _outCap, null, &res), "encode telemetry");
                        }
                    }
                    return checked((int)res.Bytes);
                }

                case "strings":
                {
                    if (_batch)
                    {
                        var items = ((BatchStrings)data).Items;
                        var n = items.Count;
                        nuint strNeed = 64;
                        var totalStrs = 0;
                        for (var i = 0; i < n; i++)
                        {
                            var ss = items[i].Items;
                            if (ss != null)
                            {
                                totalStrs += ss.Count;
                                for (var j = 0; j < ss.Count; j++)
                                    strNeed += (nuint)StrMaxBytes(ss[j]);
                            }
                        }
                        EnsureStr(strNeed);
                        var headBytes = Align16((nuint)(n * sizeof(BenchStrings)));
                        EnsureStruct(headBytes + (nuint)((totalStrs + 1) * sizeof(KilnStr)));
                        EnsureOut(strNeed + (nuint)(n * 8 + totalStrs * 8 + 64));
                        var arr = (BenchStrings*)_structBuf;
                        var pool = (KilnStr*)(_structBuf + headBytes);
                        for (var i = 0; i < n; i++)
                        {
                            var ss = items[i].Items;
                            var m = ss?.Count ?? 0;
                            arr[i].Items.Count = (ulong)m;
                            arr[i].Items.Items = m > 0 ? pool : null;
                            for (var j = 0; j < m; j++) pool[j] = PushUtf8(ss[j]);
                            pool += m;
                        }
                        CheckOk(EncodeStringsBatch(arr, (nuint)n, _outBuf, _outCap, null, &res), "encode strings batch");
                    }
                    else
                    {
                        var ss = ((Strings)data).Items;
                        var m = ss?.Count ?? 0;
                        nuint strNeed = 16;
                        for (var j = 0; j < m; j++) strNeed += (nuint)StrMaxBytes(ss[j]);
                        EnsureStr(strNeed);
                        EnsureStruct((nuint)((m + 1) * sizeof(KilnStr)));
                        EnsureOut(strNeed + (nuint)(m * 8 + 64));
                        var pool = (KilnStr*)_structBuf;
                        for (var j = 0; j < m; j++) pool[j] = PushUtf8(ss[j]);
                        BenchStrings bs = new() { Items = new KilnList { Items = m > 0 ? pool : null, Count = (ulong)m } };
                        CheckOk(EncodeStrings(&bs, _outBuf, _outCap, null, &res), "encode strings");
                    }
                    return checked((int)res.Bytes);
                }

                case "event":
                {
                    if (_batch)
                    {
                        var items = ((BatchEvent)data).Items;
                        var n = items.Count;
                        nuint strNeed = 64;
                        var totalAttrs = 0;
                        for (var i = 0; i < n; i++)
                        {
                            var e = items[i];
                            strNeed += (nuint)(StrMaxBytes(e.EventId) + StrMaxBytes(e.EventType) + StrMaxBytes(e.Producer));
                            if (e.Attrs != null)
                            {
                                totalAttrs += e.Attrs.Count;
                                for (var j = 0; j < e.Attrs.Count; j++)
                                    strNeed += (nuint)(StrMaxBytes(e.Attrs[j].Key) + StrMaxBytes(e.Attrs[j].Value));
                            }
                        }
                        EnsureStr(strNeed);
                        var headBytes = Align16((nuint)(n * sizeof(BenchEvent)));
                        EnsureStruct(headBytes + (nuint)((totalAttrs + 1) * sizeof(BenchEventAttr)));
                        EnsureOut(strNeed + (nuint)(n * 32 + totalAttrs * 16 + 64));
                        var arr = (BenchEvent*)_structBuf;
                        var pool = (BenchEventAttr*)(_structBuf + headBytes);
                        for (var i = 0; i < n; i++)
                            pool = FillEvent(items[i], &arr[i], pool);
                        CheckOk(EncodeEventBatch(arr, (nuint)n, _outBuf, _outCap, null, &res), "encode event batch");
                    }
                    else
                    {
                        var e = (Event)data;
                        nuint strNeed = (nuint)(StrMaxBytes(e.EventId) + StrMaxBytes(e.EventType) + StrMaxBytes(e.Producer) + 16);
                        var m = e.Attrs?.Count ?? 0;
                        for (var j = 0; j < m; j++)
                            strNeed += (nuint)(StrMaxBytes(e.Attrs[j].Key) + StrMaxBytes(e.Attrs[j].Value));
                        EnsureStr(strNeed);
                        EnsureStruct((nuint)((m + 1) * sizeof(BenchEventAttr)));
                        EnsureOut(strNeed + (nuint)(m * 16 + 64));
                        BenchEvent be = default;
                        FillEvent(e, &be, (BenchEventAttr*)_structBuf);
                        CheckOk(EncodeEvent(&be, _outBuf, _outCap, null, &res), "encode event");
                    }
                    return checked((int)res.Bytes);
                }

                case "table":
                case "table_project":
                {
                    List<TableRow> rows = _batch ? ((BatchTable)data).Items : new List<TableRow>(1) { (TableRow)data };
                    var n = rows.Count;
                    nuint strNeed = 64;
                    for (var i = 0; i < n; i++)
                        strNeed += (nuint)(StrMaxBytes(rows[i].FStr0) + StrMaxBytes(rows[i].FStr1));
                    EnsureStr(strNeed);
                    nuint fBytes = (nuint)n * 16u * sizeof(double);
                    nuint iBytes = (nuint)n * 4u * sizeof(long);
                    nuint sBytes = (nuint)n * 2u * (nuint)sizeof(KilnStr);
                    EnsureStruct(fBytes + iBytes + sBytes + 64);
                    EnsureOut(fBytes + iBytes + strNeed + (nuint)(n * 16 + 256));

                    var fbase = (double*)_structBuf;
                    var ibase = (long*)(_structBuf + fBytes);
                    var s0 = (KilnStr*)(_structBuf + fBytes + iBytes);
                    var s1 = s0 + n;

                    for (var r = 0; r < n; r++)
                    {
                        var row = rows[r];
                        fbase[0 * n + r] = row.FFloat0;
                        fbase[1 * n + r] = row.FFloat1;
                        fbase[2 * n + r] = row.FFloat2;
                        fbase[3 * n + r] = row.FFloat3;
                        fbase[4 * n + r] = row.FFloat4;
                        fbase[5 * n + r] = row.FFloat5;
                        fbase[6 * n + r] = row.FFloat6;
                        fbase[7 * n + r] = row.FFloat7;
                        fbase[8 * n + r] = row.FFloat8;
                        fbase[9 * n + r] = row.FFloat9;
                        fbase[10 * n + r] = row.FFloat10;
                        fbase[11 * n + r] = row.FFloat11;
                        fbase[12 * n + r] = row.FFloat12;
                        fbase[13 * n + r] = row.FFloat13;
                        fbase[14 * n + r] = row.FFloat14;
                        fbase[15 * n + r] = row.FFloat15;
                        ibase[0 * n + r] = row.FInt0;
                        ibase[1 * n + r] = row.FInt1;
                        ibase[2 * n + r] = row.FInt2;
                        ibase[3 * n + r] = row.FInt3;
                        s0[r] = PushUtf8(row.FStr0);
                        s1[r] = PushUtf8(row.FStr1);
                    }

                    BenchTableColumns tc = default;
                    var cols = (KilnList*)&tc;
                    for (var c = 0; c < 16; c++)
                        cols[c] = new KilnList { Items = fbase + (nuint)c * (nuint)n, Count = (ulong)n };
                    for (var c = 0; c < 4; c++)
                        cols[16 + c] = new KilnList { Items = ibase + (nuint)c * (nuint)n, Count = (ulong)n };
                    cols[20] = new KilnList { Items = s0, Count = (ulong)n };
                    cols[21] = new KilnList { Items = s1, Count = (ulong)n };

                    CheckOk(EncodeTableColumns(&tc, _outBuf, _outCap, null, &res), "encode table_columns");
                    return checked((int)res.Bytes);
                }

                case "nested_table":
                {
                    if (_batch)
                    {
                        var items = ((BatchNestedRow)data).Items;
                        var n = items.Count;
                        nuint strNeed = 64;
                        var totalChildren = 0;
                        for (var i = 0; i < n; i++)
                        {
                            var d = items[i];
                            strNeed += (nuint)(StrMaxBytes(d.Id) + StrMaxBytes(d.Meta?.Region));
                            if (d.Items != null)
                            {
                                totalChildren += d.Items.Count;
                                for (var j = 0; j < d.Items.Count; j++)
                                    strNeed += (nuint)StrMaxBytes(d.Items[j].Sku);
                            }
                        }
                        EnsureStr(strNeed);
                        var headBytes = Align16((nuint)(n * sizeof(BenchDocument)));
                        EnsureStruct(headBytes + (nuint)((totalChildren + 1) * sizeof(BenchDocumentItem)));
                        EnsureOut(strNeed + (nuint)(n * 48 + totalChildren * 24 + 64));
                        var arr = (BenchDocument*)_structBuf;
                        var pool = (BenchDocumentItem*)(_structBuf + headBytes);
                        for (var i = 0; i < n; i++)
                            pool = FillNestedRow(items[i], &arr[i], pool);
                        CheckOk(EncodeNestedRowBatch(arr, (nuint)n, _outBuf, _outCap, null, &res), "encode nested_table batch");
                    }
                    else
                    {
                        var d = (NestedRow)data;
                        nuint strNeed = (nuint)(StrMaxBytes(d.Id) + StrMaxBytes(d.Meta?.Region) + 16);
                        var m = d.Items?.Count ?? 0;
                        for (var j = 0; j < m; j++) strNeed += (nuint)StrMaxBytes(d.Items[j].Sku);
                        EnsureStr(strNeed);
                        EnsureStruct((nuint)((m + 1) * sizeof(BenchDocumentItem)));
                        EnsureOut(strNeed + (nuint)(m * 24 + 64));
                        BenchDocument bd = default;
                        FillNestedRow(d, &bd, (BenchDocumentItem*)_structBuf);
                        CheckOk(EncodeNestedRow(&bd, _outBuf, _outCap, null, &res), "encode nested_table");
                    }
                    return checked((int)res.Bytes);
                }

                case "signal":
                {
                    if (_batch)
                    {
                        var items = ((BatchSignal)data).Items;
                        var n = items.Count;
                        nuint strNeed = 64;
                        var totalLegs = 0;
                        for (var i = 0; i < n; i++)
                        {
                            var s = items[i];
                            strNeed += (nuint)(StrMaxBytes(s.Symbol) + StrMaxBytes(s.Venue));
                            if (s.Legs != null) totalLegs += s.Legs.Count;
                        }
                        EnsureStr(strNeed);
                        var headBytes = Align16((nuint)(n * sizeof(BenchSignal)));
                        EnsureStruct(headBytes + (nuint)((totalLegs + 1) * sizeof(BenchSignalLeg)));
                        EnsureOut(strNeed + (nuint)(n * 64 + totalLegs * 16 + 64));
                        var arr = (BenchSignal*)_structBuf;
                        var pool = (BenchSignalLeg*)(_structBuf + headBytes);
                        for (var i = 0; i < n; i++)
                            pool = FillSignal(items[i], &arr[i], pool);
                        CheckOk(EncodeSignalBatch(arr, (nuint)n, _outBuf, _outCap, null, &res), "encode signal batch");
                    }
                    else
                    {
                        var s = (Signal)data;
                        nuint strNeed = (nuint)(StrMaxBytes(s.Symbol) + StrMaxBytes(s.Venue) + 16);
                        var m = s.Legs?.Count ?? 0;
                        EnsureStr(strNeed);
                        EnsureStruct((nuint)((m + 1) * sizeof(BenchSignalLeg)));
                        EnsureOut(strNeed + (nuint)(m * 16 + 64));
                        BenchSignal bs = default;
                        FillSignal(s, &bs, (BenchSignalLeg*)_structBuf);
                        CheckOk(EncodeSignal(&bs, _outBuf, _outCap, null, &res), "encode signal");
                    }
                    return checked((int)res.Bytes);
                }

                case "grid":
                case "grid_window":
                {
                    var g = (Grid)data;
                    var nbytes = (nuint)g.Values.Length * sizeof(double);
                    EnsureOut(nbytes + 512);
                    fixed (double* vp = g.Values)
                    {
                        KilnTensor t = default;
                        KilnTensor.Init(&t);
                        t.Dtype = KILN_DTYPE_F64;
                        t.Rank = 2;
                        t.Shape[0] = (ulong)g.Ny;
                        t.Shape[1] = (ulong)g.Nx;
                        t.Data = (byte*)vp;
                        t.DataLen = (ulong)nbytes;
                        KilnTensorDir dir = new() { Items = &t, Count = 1, Flags = 2, Version = 2 };
                        CheckOk(EncodeTensors(&dir, _outBuf, _outCap, &largeOpts, &res), "encode grid");
                    }
                    return checked((int)res.Bytes);
                }

                case "tensor":
                case "tensor_view":
                {
                    var mx = (TensorMatrix)data;
                    var nbytes = (nuint)mx.Values.Length * sizeof(float);
                    EnsureOut(nbytes + 512);
                    fixed (float* vp = mx.Values)
                    {
                        KilnTensor t = default;
                        KilnTensor.Init(&t);
                        t.Dtype = KILN_DTYPE_F32;
                        t.Rank = 2;
                        t.Shape[0] = (ulong)mx.Rows;
                        t.Shape[1] = (ulong)mx.Cols;
                        t.Data = (byte*)vp;
                        t.DataLen = (ulong)nbytes;
                        KilnTensorDir dir = new() { Items = &t, Count = 1, Flags = 2, Version = 2 };
                        CheckOk(EncodeTensors(&dir, _outBuf, _outCap, &largeOpts, &res), "encode tensor");
                    }
                    return checked((int)res.Bytes);
                }

                case "prompt":
                {
                    var p = (Prompt)data;
                    var nbytes = (nuint)p.InputIds.Length * sizeof(long);
                    EnsureOut(nbytes * 3 + 1024);
                    fixed (long* p0 = p.InputIds)
                    fixed (long* p1 = p.AttentionMask)
                    fixed (long* p2 = p.PositionIds)
                    {
                        KilnTensor* ts = stackalloc KilnTensor[3];
                        SetTensor2D(&ts[0], KILN_DTYPE_I64, (ulong)p.Batch, (ulong)p.Seq, p0, nbytes);
                        SetTensor2D(&ts[1], KILN_DTYPE_I64, (ulong)p.Batch, (ulong)p.Seq, p1, nbytes);
                        SetTensor2D(&ts[2], KILN_DTYPE_I64, (ulong)p.Batch, (ulong)p.Seq, p2, nbytes);
                        KilnTensorDir dir = new() { Items = ts, Count = 3, Flags = 2, Version = 2 };
                        CheckOk(EncodeTensors(&dir, _outBuf, _outCap, &largeOpts, &res), "encode prompt");
                    }
                    return checked((int)res.Bytes);
                }

                case "shard":
                {
                    var sh = (Shard)data;
                    var b0 = (nuint)sh.TokEmb.Length * sizeof(float);
                    var b1 = (nuint)sh.Attn.Length * sizeof(float);
                    var b2 = (nuint)sh.FfnWeight.Length * sizeof(float);
                    var b3 = (nuint)sh.Norm.Length * sizeof(float);
                    EnsureOut(b0 + b1 + b2 + b3 + 2048);
                    fixed (float* p0 = sh.TokEmb)
                    fixed (float* p1 = sh.Attn)
                    fixed (float* p2 = sh.FfnWeight)
                    fixed (float* p3 = sh.Norm)
                    {
                        KilnTensor* ts = stackalloc KilnTensor[4];
                        SetTensor2D(&ts[0], KILN_DTYPE_F32, (ulong)sh.Vocab, (ulong)sh.Hidden, p0, b0);
                        SetTensor2D(&ts[1], KILN_DTYPE_F32, (ulong)sh.Hidden, (ulong)sh.Hidden, p1, b1);
                        SetTensor2D(&ts[2], KILN_DTYPE_F32, (ulong)sh.Ffn, (ulong)sh.Hidden, p2, b2);
                        SetTensor1D(&ts[3], KILN_DTYPE_F32, (ulong)sh.Hidden, p3, b3);
                        KilnTensorDir dir = new() { Items = ts, Count = 4, Flags = 2, Version = 2 };
                        CheckOk(EncodeTensors(&dir, _outBuf, _outCap, &largeOpts, &res), "encode shard");
                    }
                    return checked((int)res.Bytes);
                }

                case "request":
                {
                    var rq = (InferenceRequest)data;
                    var p = rq.Inputs;
                    var strNeed = (nuint)(StrMaxBytes(rq.Model) + 16);
                    var nbytes = (nuint)p.InputIds.Length * sizeof(long);
                    EnsureStr(strNeed);
                    EnsureOut(strNeed + nbytes * 3 + 1024);
                    fixed (long* p0 = p.InputIds)
                    fixed (long* p1 = p.AttentionMask)
                    fixed (long* p2 = p.PositionIds)
                    {
                        KilnTensor* ts = stackalloc KilnTensor[3];
                        SetTensor2D(&ts[0], KILN_DTYPE_I64, (ulong)p.Batch, (ulong)p.Seq, p0, nbytes);
                        SetTensor2D(&ts[1], KILN_DTYPE_I64, (ulong)p.Batch, (ulong)p.Seq, p1, nbytes);
                        SetTensor2D(&ts[2], KILN_DTYPE_I64, (ulong)p.Batch, (ulong)p.Seq, p2, nbytes);
                        BenchRequest br = new()
                        {
                            RequestId = rq.RequestId,
                            Model = PushUtf8(rq.Model),
                            Temperature = rq.Temperature,
                            Inputs = new KilnTensorDir { Items = ts, Count = 3, Flags = 2, Version = 2 },
                        };
                        CheckOk(EncodeRequest(&br, _outBuf, _outCap, &largeOpts, &res), "encode request");
                    }
                    return checked((int)res.Bytes);
                }

                default:
                    throw new NotSupportedException("gld-kiln-asm unsupported fixture: " + _fixture);
            }
        }

        // ==================== DECODE ====================

        object DecodeFromMemory(ReadOnlyMemory<byte> mem)
        {
            var span = mem.Span;
            var len = (nuint)span.Length;
            KilnResult res = default;
            KilnReadOpts largeOpts = new() { MaxCount = KILN_LARGE_CAP, MaxBytes = KILN_LARGE_CAP };

            fixed (byte* src = span)
            {
                switch (_fixture)
                {
                    case "message":
                    {
                        var arena = ResetArena(Math.Max(len * 4, 65536));
                        if (_batch)
                        {
                            BenchMessage* arr = null;
                            nuint cnt = 0;
                            CheckOk(DecodeMessageBatch(src, len, &arr, &cnt, &arena, null, &res), "decode message batch");
                            var list = new List<Message>((int)cnt);
                            for (nuint i = 0; i < cnt; i++) list.Add(ReadMessage(&arr[i]));
                            return new BatchMessage { Items = list };
                        }
                        else
                        {
                            BenchMessage bm = default;
                            CheckOk(DecodeMessage(src, len, &bm, &arena, null, &res), "decode message");
                            return ReadMessage(&bm);
                        }
                    }

                    case "document":
                    {
                        var arena = ResetArena(Math.Max(len * 4, 65536));
                        if (_batch)
                        {
                            BenchDocument* arr = null;
                            nuint cnt = 0;
                            CheckOk(DecodeDocumentBatch(src, len, &arr, &cnt, &arena, null, &res), "decode document batch");
                            var list = new List<Document>((int)cnt);
                            for (nuint i = 0; i < cnt; i++) list.Add(ReadDocument(&arr[i]));
                            return new BatchDocument { Items = list };
                        }
                        else
                        {
                            BenchDocument bd = default;
                            CheckOk(DecodeDocument(src, len, &bd, &arena, null, &res), "decode document");
                            return ReadDocument(&bd);
                        }
                    }

                    case "telemetry":
                    {
                        var arena = ResetArena(Math.Max(len * 4, 65536));
                        if (_batch)
                        {
                            BenchTelemetry* arr = null;
                            nuint cnt = 0;
                            CheckOk(DecodeTelemetryBatch(src, len, &arr, &cnt, &arena, null, &res), "decode telemetry batch");
                            var list = new List<Telemetry>((int)cnt);
                            for (nuint i = 0; i < cnt; i++) list.Add(ReadTelemetry(&arr[i]));
                            return new BatchTelemetry { Items = list };
                        }
                        else
                        {
                            BenchTelemetry bt = default;
                            CheckOk(DecodeTelemetry(src, len, &bt, &arena, null, &res), "decode telemetry");
                            return ReadTelemetry(&bt);
                        }
                    }

                    case "strings":
                    {
                        var arena = ResetArena(Math.Max(len * 4, 65536));
                        if (_batch)
                        {
                            BenchStrings* arr = null;
                            nuint cnt = 0;
                            CheckOk(DecodeStringsBatch(src, len, &arr, &cnt, &arena, null, &res), "decode strings batch");
                            var list = new List<Strings>((int)cnt);
                            for (nuint i = 0; i < cnt; i++) list.Add(ReadStrings(&arr[i]));
                            return new BatchStrings { Items = list };
                        }
                        else
                        {
                            BenchStrings bs = default;
                            CheckOk(DecodeStrings(src, len, &bs, &arena, null, &res), "decode strings");
                            return ReadStrings(&bs);
                        }
                    }

                    case "event":
                    {
                        var arena = ResetArena(Math.Max(len * 4, 65536));
                        if (_batch)
                        {
                            BenchEvent* arr = null;
                            nuint cnt = 0;
                            CheckOk(DecodeEventBatch(src, len, &arr, &cnt, &arena, null, &res), "decode event batch");
                            var list = new List<Event>((int)cnt);
                            for (nuint i = 0; i < cnt; i++) list.Add(ReadEvent(&arr[i]));
                            return new BatchEvent { Items = list };
                        }
                        else
                        {
                            BenchEvent be = default;
                            CheckOk(DecodeEvent(src, len, &be, &arena, null, &res), "decode event");
                            return ReadEvent(&be);
                        }
                    }

                    case "table":
                    {
                        var arena = ResetArena(Math.Max(len * 2, 262144));
                        BenchTableColumns tc = default;
                        CheckOk(DecodeTableColumns(src, len, &tc, &arena, null, &res), "decode table_columns");
                        var n = checked((int)tc.FFloat0.Count);
                        var cols = (KilnList*)&tc;
                        var fptrs = stackalloc byte*[16];
                        for (var c = 0; c < 16; c++) fptrs[c] = (byte*)cols[c].Items;
                        var iptrs = stackalloc byte*[4];
                        for (var c = 0; c < 4; c++) iptrs[c] = (byte*)cols[16 + c].Items;
                        var s0 = (KilnStr*)cols[20].Items;
                        var s1 = (KilnStr*)cols[21].Items;

                        var list = new List<TableRow>(n);
                        for (var r = 0; r < n; r++)
                        {
                            var off = (nuint)r * 8u;
                            list.Add(new TableRow
                            {
                                FFloat0 = Unsafe.ReadUnaligned<double>(fptrs[0] + off),
                                FFloat1 = Unsafe.ReadUnaligned<double>(fptrs[1] + off),
                                FFloat2 = Unsafe.ReadUnaligned<double>(fptrs[2] + off),
                                FFloat3 = Unsafe.ReadUnaligned<double>(fptrs[3] + off),
                                FFloat4 = Unsafe.ReadUnaligned<double>(fptrs[4] + off),
                                FFloat5 = Unsafe.ReadUnaligned<double>(fptrs[5] + off),
                                FFloat6 = Unsafe.ReadUnaligned<double>(fptrs[6] + off),
                                FFloat7 = Unsafe.ReadUnaligned<double>(fptrs[7] + off),
                                FFloat8 = Unsafe.ReadUnaligned<double>(fptrs[8] + off),
                                FFloat9 = Unsafe.ReadUnaligned<double>(fptrs[9] + off),
                                FFloat10 = Unsafe.ReadUnaligned<double>(fptrs[10] + off),
                                FFloat11 = Unsafe.ReadUnaligned<double>(fptrs[11] + off),
                                FFloat12 = Unsafe.ReadUnaligned<double>(fptrs[12] + off),
                                FFloat13 = Unsafe.ReadUnaligned<double>(fptrs[13] + off),
                                FFloat14 = Unsafe.ReadUnaligned<double>(fptrs[14] + off),
                                FFloat15 = Unsafe.ReadUnaligned<double>(fptrs[15] + off),
                                FInt0 = Unsafe.ReadUnaligned<long>(iptrs[0] + off),
                                FInt1 = Unsafe.ReadUnaligned<long>(iptrs[1] + off),
                                FInt2 = Unsafe.ReadUnaligned<long>(iptrs[2] + off),
                                FInt3 = Unsafe.ReadUnaligned<long>(iptrs[3] + off),
                                FStr0 = ReadUtf8(s0[r]),
                                FStr1 = ReadUtf8(s1[r]),
                            });
                        }
                        if (!_batch)
                            return list.Count > 0 ? list[0] : new TableRow();
                        return new BatchTable { Items = list };
                    }

                    case "table_project":
                    {
                        // Decode ONLY column 0 (f_float_0) via KILN_OPT_EMBEDDED; skip columns 1..21 in O(1).
                        var arena = ResetArena(65536);
                        KilnReadOpts embOpts = new() { Flags = KILN_OPT_EMBEDDED };
                        BenchTableProject proj = default;
                        CheckOk(DecodeTableProject(src, len, &proj, &arena, &embOpts, &res), "decode table_project");
                        var n = checked((int)proj.FFloat0.Count);
                        var list = new List<double>(n);
                        CollectionsMarshal.SetCount(list, n);
                        if (n > 0)
                        {
                            fixed (double* dst = CollectionsMarshal.AsSpan(list))
                                Buffer.MemoryCopy(proj.FFloat0.Items, dst, n * 8L, n * 8L);
                        }
                        return list;
                    }

                    case "nested_table":
                    {
                        var arena = ResetArena(Math.Max(len * 4, 65536));
                        if (_batch)
                        {
                            BenchDocument* arr = null;
                            nuint cnt = 0;
                            CheckOk(DecodeNestedRowBatch(src, len, &arr, &cnt, &arena, null, &res), "decode nested_table batch");
                            var list = new List<NestedRow>((int)cnt);
                            for (nuint i = 0; i < cnt; i++) list.Add(ReadNestedRow(&arr[i]));
                            return new BatchNestedRow { Items = list };
                        }
                        else
                        {
                            BenchDocument bd = default;
                            CheckOk(DecodeNestedRow(src, len, &bd, &arena, null, &res), "decode nested_table");
                            return ReadNestedRow(&bd);
                        }
                    }

                    case "signal":
                    {
                        var arena = ResetArena(Math.Max(len * 4, 65536));
                        if (_batch)
                        {
                            BenchSignal* arr = null;
                            nuint cnt = 0;
                            CheckOk(DecodeSignalBatch(src, len, &arr, &cnt, &arena, null, &res), "decode signal batch");
                            var list = new List<Signal>((int)cnt);
                            for (nuint i = 0; i < cnt; i++) list.Add(ReadSignal(&arr[i]));
                            return new BatchSignal { Items = list };
                        }
                        else
                        {
                            BenchSignal bs = default;
                            CheckOk(DecodeSignal(src, len, &bs, &arena, null, &res), "decode signal");
                            return ReadSignal(&bs);
                        }
                    }

                    case "grid":
                    case "grid_window":
                    {
                        var arena = ResetArena(65536);
                        KilnTensorDir dir = default;
                        CheckOk(DecodeTensors(src, len, &dir, &arena, &largeOpts, &res), "decode grid");
                        if (dir.Count != 1) throw new InvalidOperationException("grid tensor count != 1");
                        var t = &dir.Items[0];
                        var ny = checked((int)t->Shape[0]);
                        var nx = checked((int)t->Shape[1]);
                        if (_window)
                        {
                            var win = new double[_wx * _wy];
                            var rowBytes = (long)_wx * sizeof(double);
                            fixed (double* dst = win)
                            {
                                var dstB = (byte*)dst;
                                for (var r = 0; r < _wy; r++)
                                {
                                    var srcOff = ((long)(_y0 + r) * nx + _x0) * sizeof(double);
                                    Buffer.MemoryCopy(t->Data + srcOff, dstB + (long)r * rowBytes, rowBytes, rowBytes);
                                }
                            }
                            return win;
                        }
                        else
                        {
                            var vals = new double[nx * ny];
                            var totalBytes = (long)vals.Length * sizeof(double);
                            fixed (double* dst = vals)
                                Buffer.MemoryCopy(t->Data, dst, totalBytes, totalBytes);
                            return vals;
                        }
                    }

                    case "tensor":
                    {
                        var arena = ResetArena(65536);
                        KilnTensorDir dir = default;
                        CheckOk(DecodeTensors(src, len, &dir, &arena, &largeOpts, &res), "decode tensor");
                        if (dir.Count != 1) throw new InvalidOperationException("tensor count != 1");
                        var t = &dir.Items[0];
                        var rows = checked((int)t->Shape[0]);
                        var cols = checked((int)t->Shape[1]);
                        var vals = new float[rows * cols];
                        var totalBytes = (long)vals.Length * sizeof(float);
                        fixed (float* dst = vals)
                            Buffer.MemoryCopy(t->Data, dst, totalBytes, totalBytes);
                        return new TensorMatrix { Rows = rows, Cols = cols, Values = vals };
                    }

                    case "tensor_view":
                    {
                        // Genuine zero-copy borrow of the caller's ReadOnlyMemory<byte>.
                        var arena = ResetArena(65536);
                        KilnTensorDir dir = default;
                        CheckOk(DecodeTensors(src, len, &dir, &arena, &largeOpts, &res), "decode tensor_view");
                        if (dir.Count != 1) throw new InvalidOperationException("tensor_view count != 1");
                        var t = &dir.Items[0];
                        var rows = checked((int)t->Shape[0]);
                        var cols = checked((int)t->Shape[1]);
                        var dataLen = checked((int)t->DataLen);
                        var offset = checked((int)(t->Data - src));
                        if (offset < 0 || offset + dataLen > mem.Length)
                            throw new InvalidOperationException("tensor_view payload out of bounds");
                        return new KilnSerializerSer.BorrowedMatrix
                        {
                            Rows = rows,
                            Cols = cols,
                            Values = mem.Slice(offset, dataLen),
                        };
                    }

                    case "prompt":
                    {
                        var arena = ResetArena(65536);
                        KilnTensorDir dir = default;
                        CheckOk(DecodeTensors(src, len, &dir, &arena, &largeOpts, &res), "decode prompt");
                        return ReadPromptDir(&dir);
                    }

                    case "shard":
                    {
                        var arena = ResetArena(65536);
                        KilnTensorDir dir = default;
                        CheckOk(DecodeTensors(src, len, &dir, &arena, &largeOpts, &res), "decode shard");
                        if (dir.Count != 4) throw new InvalidOperationException("shard count != 4");
                        var vocab = checked((int)dir.Items[0].Shape[0]);
                        var hidden = checked((int)dir.Items[0].Shape[1]);
                        var ffn = checked((int)dir.Items[2].Shape[0]);
                        return new Shard
                        {
                            Vocab = vocab,
                            Hidden = hidden,
                            Ffn = ffn,
                            TokEmb = CopyF32(&dir.Items[0]),
                            Attn = CopyF32(&dir.Items[1]),
                            FfnWeight = CopyF32(&dir.Items[2]),
                            Norm = CopyF32(&dir.Items[3]),
                        };
                    }

                    case "request":
                    {
                        var arena = ResetArena(65536);
                        BenchRequest br = default;
                        CheckOk(DecodeRequest(src, len, &br, &arena, &largeOpts, &res), "decode request");
                        return new InferenceRequest
                        {
                            RequestId = br.RequestId,
                            Model = ReadUtf8(br.Model),
                            Temperature = br.Temperature,
                            Inputs = ReadPromptDir(&br.Inputs),
                        };
                    }

                    default:
                        throw new NotSupportedException("gld-kiln-asm unsupported fixture: " + _fixture);
                }
            }
        }

        // ==================== Helpers ====================

        void FillMessage(Message m, BenchMessage* dst)
        {
            dst->FBool = m.FBool ? (byte)1 : (byte)0;
            dst->FInt32 = m.FInt32;
            dst->FInt64 = m.FInt64;
            dst->FFloat64 = m.FFloat64;
            dst->FString = PushUtf8(m.FString);
            dst->FBool2 = m.FBool2 ? (byte)1 : (byte)0;
            dst->FInt322 = m.FInt322;
            dst->FString2 = PushUtf8(m.FString2);
        }

        static Message ReadMessage(BenchMessage* src) => new()
        {
            FBool = src->FBool != 0,
            FInt32 = src->FInt32,
            FInt64 = src->FInt64,
            FFloat64 = src->FFloat64,
            FString = ReadUtf8(src->FString),
            FBool2 = src->FBool2 != 0,
            FInt322 = src->FInt322,
            FString2 = ReadUtf8(src->FString2),
        };

        BenchDocumentItem* FillDocument(Document d, BenchDocument* dst, BenchDocumentItem* pool)
        {
            dst->Id = PushUtf8(d.Id);
            dst->Status = d.Status;
            dst->Meta.Region = PushUtf8(d.Meta?.Region);
            dst->Meta.Version = d.Meta?.Version ?? 0;
            var ch = d.Items;
            var n = ch?.Count ?? 0;
            dst->Items.Count = (ulong)n;
            dst->Items.Items = n > 0 ? pool : null;
            for (var j = 0; j < n; j++)
            {
                var it = ch[j];
                pool[j].Sku = PushUtf8(it.Sku);
                pool[j].Qty = it.Qty;
                pool[j].PriceMinor = it.PriceMinor;
            }
            return pool + n;
        }

        static Document ReadDocument(BenchDocument* src)
        {
            var n = checked((int)src->Items.Count);
            var list = new List<DocumentItem>(n);
            var items = (BenchDocumentItem*)src->Items.Items;
            for (var j = 0; j < n; j++)
            {
                list.Add(new DocumentItem
                {
                    Sku = ReadUtf8(items[j].Sku),
                    Qty = items[j].Qty,
                    PriceMinor = items[j].PriceMinor,
                });
            }
            return new Document
            {
                Id = ReadUtf8(src->Id),
                Status = src->Status,
                Meta = new DocumentMeta { Region = ReadUtf8(src->Meta.Region), Version = src->Meta.Version },
                Items = list,
            };
        }

        BenchDocumentItem* FillNestedRow(NestedRow d, BenchDocument* dst, BenchDocumentItem* pool)
        {
            dst->Id = PushUtf8(d.Id);
            dst->Status = d.Status;
            dst->Meta.Region = PushUtf8(d.Meta?.Region);
            dst->Meta.Version = d.Meta?.Version ?? 0;
            var ch = d.Items;
            var n = ch?.Count ?? 0;
            dst->Items.Count = (ulong)n;
            dst->Items.Items = n > 0 ? pool : null;
            for (var j = 0; j < n; j++)
            {
                var it = ch[j];
                pool[j].Sku = PushUtf8(it.Sku);
                pool[j].Qty = it.Qty;
                pool[j].PriceMinor = it.PriceMinor;
            }
            return pool + n;
        }

        static NestedRow ReadNestedRow(BenchDocument* src)
        {
            var n = checked((int)src->Items.Count);
            var list = new List<NestedItem>(n);
            var items = (BenchDocumentItem*)src->Items.Items;
            for (var j = 0; j < n; j++)
            {
                list.Add(new NestedItem
                {
                    Sku = ReadUtf8(items[j].Sku),
                    Qty = items[j].Qty,
                    PriceMinor = items[j].PriceMinor,
                });
            }
            return new NestedRow
            {
                Id = ReadUtf8(src->Id),
                Status = src->Status,
                Meta = new NestedMeta { Region = ReadUtf8(src->Meta.Region), Version = src->Meta.Version },
                Items = list,
            };
        }

        static Telemetry ReadTelemetry(BenchTelemetry* src)
        {
            var nt = checked((int)src->Tags.Count);
            var tags = new List<string>(nt);
            var tptr = (KilnStr*)src->Tags.Items;
            for (var j = 0; j < nt; j++) tags.Add(ReadUtf8(tptr[j]));

            var nv = checked((int)src->Values.Count);
            var vals = new List<double>(nv);
            CollectionsMarshal.SetCount(vals, nv);
            if (nv > 0)
            {
                fixed (double* dst = CollectionsMarshal.AsSpan(vals))
                    Buffer.MemoryCopy(src->Values.Items, dst, nv * 8L, nv * 8L);
            }
            return new Telemetry { Source = ReadUtf8(src->Source), Ts = src->Ts, Tags = tags, Values = vals };
        }

        static Strings ReadStrings(BenchStrings* src)
        {
            var n = checked((int)src->Items.Count);
            var list = new List<string>(n);
            var sptr = (KilnStr*)src->Items.Items;
            for (var j = 0; j < n; j++) list.Add(ReadUtf8(sptr[j]));
            return new Strings { Items = list };
        }

        BenchEventAttr* FillEvent(Event e, BenchEvent* dst, BenchEventAttr* pool)
        {
            dst->EventId = PushUtf8(e.EventId);
            dst->EventType = PushUtf8(e.EventType);
            dst->OccurredAt = e.OccurredAt;
            dst->Producer = PushUtf8(e.Producer);
            var attrs = e.Attrs;
            var n = attrs?.Count ?? 0;
            dst->Attrs.Count = (ulong)n;
            dst->Attrs.Items = n > 0 ? pool : null;
            for (var j = 0; j < n; j++)
            {
                pool[j].Key = PushUtf8(attrs[j].Key);
                pool[j].Value = PushUtf8(attrs[j].Value);
            }
            return pool + n;
        }

        static Event ReadEvent(BenchEvent* src)
        {
            var n = checked((int)src->Attrs.Count);
            var list = new List<EventAttr>(n);
            var aptr = (BenchEventAttr*)src->Attrs.Items;
            for (var j = 0; j < n; j++)
            {
                list.Add(new EventAttr { Key = ReadUtf8(aptr[j].Key), Value = ReadUtf8(aptr[j].Value) });
            }
            return new Event
            {
                EventId = ReadUtf8(src->EventId),
                EventType = ReadUtf8(src->EventType),
                OccurredAt = src->OccurredAt,
                Producer = ReadUtf8(src->Producer),
                Attrs = list,
            };
        }

        BenchSignalLeg* FillSignal(Signal s, BenchSignal* dst, BenchSignalLeg* pool)
        {
            dst->Seq = s.Seq;
            dst->Ts = s.Ts;
            dst->PriceMantissa = s.PriceMantissa;
            dst->Qty = s.Qty;
            dst->Flags = s.Flags;
            dst->Symbol = PushUtf8(s.Symbol);
            dst->Venue = PushUtf8(s.Venue);
            var legs = s.Legs;
            var n = legs?.Count ?? 0;
            dst->Legs.Count = (ulong)n;
            dst->Legs.Items = n > 0 ? pool : null;
            for (var j = 0; j < n; j++)
            {
                pool[j].LegId = legs[j].LegId;
                pool[j].LegQty = legs[j].LegQty;
                pool[j].LegPad = legs[j].LegPad;
            }
            return pool + n;
        }

        static Signal ReadSignal(BenchSignal* src)
        {
            var n = checked((int)src->Legs.Count);
            var list = new List<SignalLeg>(n);
            var lptr = (BenchSignalLeg*)src->Legs.Items;
            for (var j = 0; j < n; j++)
            {
                list.Add(new SignalLeg { LegId = lptr[j].LegId, LegQty = lptr[j].LegQty, LegPad = lptr[j].LegPad });
            }
            return new Signal
            {
                Seq = src->Seq,
                Ts = src->Ts,
                PriceMantissa = src->PriceMantissa,
                Qty = src->Qty,
                Flags = src->Flags,
                Symbol = ReadUtf8(src->Symbol),
                Venue = ReadUtf8(src->Venue),
                Legs = list,
            };
        }

        static void SetTensor2D(KilnTensor* t, ushort dtype, ulong d0, ulong d1, void* data, nuint nbytes)
        {
            KilnTensor.Init(t);
            t->Dtype = dtype;
            t->Rank = 2;
            t->Shape[0] = d0;
            t->Shape[1] = d1;
            t->Data = (byte*)data;
            t->DataLen = (ulong)nbytes;
        }

        static void SetTensor1D(KilnTensor* t, ushort dtype, ulong d0, void* data, nuint nbytes)
        {
            KilnTensor.Init(t);
            t->Dtype = dtype;
            t->Rank = 1;
            t->Shape[0] = d0;
            t->Data = (byte*)data;
            t->DataLen = (ulong)nbytes;
        }

        static float[] CopyF32(KilnTensor* t)
        {
            var n = checked((int)(t->DataLen / 4));
            var arr = new float[n];
            if (n > 0)
            {
                fixed (float* dst = arr)
                    Buffer.MemoryCopy(t->Data, dst, (long)t->DataLen, (long)t->DataLen);
            }
            return arr;
        }

        static long[] CopyI64(KilnTensor* t)
        {
            var n = checked((int)(t->DataLen / 8));
            var arr = new long[n];
            if (n > 0)
            {
                fixed (long* dst = arr)
                    Buffer.MemoryCopy(t->Data, dst, (long)t->DataLen, (long)t->DataLen);
            }
            return arr;
        }

        static Prompt ReadPromptDir(KilnTensorDir* dir)
        {
            if (dir->Count != 3) throw new InvalidOperationException("prompt count != 3");
            return new Prompt
            {
                Batch = checked((int)dir->Items[0].Shape[0]),
                Seq = checked((int)dir->Items[0].Shape[1]),
                InputIds = CopyI64(&dir->Items[0]),
                AttentionMask = CopyI64(&dir->Items[1]),
                PositionIds = CopyI64(&dir->Items[2]),
            };
        }
    }
}
