using System;
using System.Buffers.Binary;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using Apache.Arrow;
using Apache.Arrow.Ipc;
using Apache.Arrow.Types;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Arrow IPC stream (not the file format). String path is Base64 of that stream.
    /// Stream path writes the same bytes (adapted). table_project reads only FFloat0's
    /// value buffer; it does not build the other columns.
    /// </summary>
    internal sealed class ArrowIpcSerializerSer : SerDeser
    {
        static readonly KeyValuePair<string, string>[] NoMeta = System.Array.Empty<KeyValuePair<string, string>>();
        static readonly Encoding Utf8 = Encoding.UTF8;

        bool _batch;
        Type _rowType;
        PropertyInfo _itemsProp;
        string _kind;

        public override string Name => "arrow-ipc";

        public override bool Supports(string testDataName) =>
            testDataName is "table" or "table_project" or "nested_table" or "signal";

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _batch = _primaryType.Name.StartsWith("Batch", StringComparison.Ordinal);
            if (_batch)
            {
                _itemsProp = _primaryType.GetProperty("Items")
                    ?? throw new InvalidOperationException("batch type has no Items");
                _rowType = _itemsProp.PropertyType.GetGenericArguments()[0];
            }
            else
            {
                _rowType = _primaryType;
            }
            _kind = _rowType.Name;
        }

        public override string Serialize(object serializable)
            => Convert.ToBase64String(Encode(serializable));

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return IsTableProject ? ProjectFFloat0(bytes) : Decode(bytes);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = Encode(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            if (inputStream.CanSeek)
                inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            var bytes = ms.ToArray();
            return IsTableProject ? ProjectFFloat0(bytes) : Decode(bytes);
        }

        byte[] Encode(object data)
        {
            var rows = RowsOf(data);
            RecordBatch batch = _kind switch
            {
                "TableRow" => BuildTable(rows),
                "NestedRow" => BuildNested(rows),
                "Signal" => BuildSignal(rows),
                _ => throw new NotSupportedException(_kind),
            };
            using (batch)
            {
                var ms = new MemoryStream();
                using (var writer = new ArrowStreamWriter(ms, batch.Schema, leaveOpen: true))
                {
                    writer.WriteRecordBatch(batch);
                    writer.WriteEnd();
                }
                return ms.ToArray();
            }
        }

        object Decode(byte[] bytes)
        {
            using var reader = new ArrowStreamReader(new ReadOnlyMemory<byte>(bytes));
            using var batch = reader.ReadNextRecordBatch()
                ?? throw new InvalidOperationException("arrow-ipc stream has no record batch");
            int n = batch.Length;
            var rows = new object[n];
            for (int i = 0; i < n; i++)
                rows[i] = Activator.CreateInstance(_rowType);
            for (int c = 0; c < batch.ColumnCount; c++)
            {
                var field = batch.Schema.GetFieldByIndex(c);
                var prop = _rowType.GetProperty(field.Name)
                    ?? throw new InvalidOperationException("arrow column has no property " + field.Name);
                var array = batch.Column(c);
                for (int i = 0; i < n; i++)
                    prop.SetValue(rows[i], ReadValue(prop.PropertyType, field, array, i));
            }
            if (!_batch)
                return rows.Length == 0 ? Activator.CreateInstance(_rowType) : rows[0];
            var list = (IList)Activator.CreateInstance(typeof(List<>).MakeGenericType(_rowType));
            foreach (var row in rows)
                list.Add(row);
            var wrapped = Activator.CreateInstance(_primaryType);
            _itemsProp.SetValue(wrapped, list);
            return wrapped;
        }

        IList RowsOf(object data)
        {
            if (!_batch)
                return new object[] { data };
            var items = _itemsProp.GetValue(data) as IList;
            return items ?? throw new InvalidOperationException("batch Items is not a list");
        }

        static RecordBatch BuildTable(IList rows)
        {
            var fields = new List<Field>(22);
            var arrays = new List<IArrowArray>(22);
            for (int i = 0; i < 16; i++)
                Add(fields, arrays, "FFloat" + i, new DoubleType(), Doubles(rows, "FFloat" + i));
            for (int i = 0; i < 4; i++)
                Add(fields, arrays, "FInt" + i, new Int64Type(), Int64s(rows, "FInt" + i));
            Add(fields, arrays, "FStr0", new StringType(), Strings(rows, "FStr0"));
            Add(fields, arrays, "FStr1", new StringType(), Strings(rows, "FStr1"));
            return Finish(fields, arrays, rows.Count);
        }

        static RecordBatch BuildNested(IList rows)
        {
            var fields = new List<Field>(4);
            var arrays = new List<IArrowArray>(4);
            Add(fields, arrays, "Id", new StringType(), Strings(rows, "Id"));
            Add(fields, arrays, "Status", new Int32Type(), Int32s(rows, "Status"));
            var metaType = new StructType(new[]
            {
                FieldOf("Region", new StringType()),
                FieldOf("Version", new Int32Type()),
            });
            var meta = BuildMeta(rows, metaType);
            Add(fields, arrays, "Meta", metaType, meta);
            var itemType = new StructType(new[]
            {
                FieldOf("Sku", new StringType()),
                FieldOf("Qty", new Int32Type()),
                FieldOf("PriceMinor", new Int64Type()),
            });
            Add(fields, arrays, "Items", new ListType(FieldOf("item", itemType)), BuildItems(rows, itemType));
            return Finish(fields, arrays, rows.Count);
        }

        static RecordBatch BuildSignal(IList rows)
        {
            var fields = new List<Field>(8);
            var arrays = new List<IArrowArray>(8);
            Add(fields, arrays, "Seq", new Int64Type(), Int64s(rows, "Seq"));
            Add(fields, arrays, "Ts", new Int64Type(), Int64s(rows, "Ts"));
            Add(fields, arrays, "PriceMantissa", new Int64Type(), Int64s(rows, "PriceMantissa"));
            Add(fields, arrays, "Qty", new Int32Type(), Int32s(rows, "Qty"));
            Add(fields, arrays, "Flags", new Int32Type(), Int32s(rows, "Flags"));
            Add(fields, arrays, "Symbol", new StringType(), Strings(rows, "Symbol"));
            Add(fields, arrays, "Venue", new StringType(), Strings(rows, "Venue"));
            var legType = new StructType(new[]
            {
                FieldOf("LegId", new Int64Type()),
                FieldOf("LegQty", new Int32Type()),
                FieldOf("LegPad", new Int32Type()),
            });
            Add(fields, arrays, "Legs", new ListType(FieldOf("item", legType)), BuildLegs(rows, legType));
            return Finish(fields, arrays, rows.Count);
        }

        static RecordBatch Finish(List<Field> fields, List<IArrowArray> arrays, int length)
        {
            var schema = new Schema(fields, NoMeta);
            return new RecordBatch(schema, arrays, length);
        }

        static void Add(List<Field> fields, List<IArrowArray> arrays, string name, IArrowType type, IArrowArray array)
        {
            fields.Add(FieldOf(name, type));
            arrays.Add(array);
        }

        static Field FieldOf(string name, IArrowType type) => new Field(name, type, false, NoMeta);

        static object Prop(object row, string name) =>
            row.GetType().GetProperty(name).GetValue(row);

        static DoubleArray Doubles(IList rows, string name)
        {
            var b = new DoubleArray.Builder();
            for (int i = 0; i < rows.Count; i++)
                b.Append((double)Prop(rows[i], name));
            return b.Build();
        }

        static Int64Array Int64s(IList rows, string name)
        {
            var b = new Int64Array.Builder();
            for (int i = 0; i < rows.Count; i++)
                b.Append(Convert.ToInt64(Prop(rows[i], name)));
            return b.Build();
        }

        static Int32Array Int32s(IList rows, string name)
        {
            var b = new Int32Array.Builder();
            for (int i = 0; i < rows.Count; i++)
                b.Append(Convert.ToInt32(Prop(rows[i], name)));
            return b.Build();
        }

        static StringArray Strings(IList rows, string name)
        {
            var b = new StringArray.Builder();
            for (int i = 0; i < rows.Count; i++)
                b.Append(Prop(rows[i], name) as string ?? "", Utf8);
            return b.Build();
        }

        static StructArray BuildMeta(IList rows, StructType metaType)
        {
            var region = new StringArray.Builder();
            var version = new Int32Array.Builder();
            for (int i = 0; i < rows.Count; i++)
            {
                var meta = Prop(rows[i], "Meta");
                region.Append(Prop(meta, "Region") as string ?? "", Utf8);
                version.Append(Convert.ToInt32(Prop(meta, "Version")));
            }
            return new StructArray(metaType, rows.Count, new IArrowArray[] { region.Build(), version.Build() },
                ArrowBuffer.Empty, 0, 0);
        }

        static ListArray BuildItems(IList rows, StructType itemType)
        {
            var sku = new StringArray.Builder();
            var qty = new Int32Array.Builder();
            var price = new Int64Array.Builder();
            var offsets = new ArrowBuffer.Builder<int>(rows.Count + 1);
            offsets.Append(0);
            int total = 0;
            for (int i = 0; i < rows.Count; i++)
            {
                var items = Prop(rows[i], "Items") as IList;
                if (items != null)
                {
                    foreach (var it in items)
                    {
                        sku.Append(Prop(it, "Sku") as string ?? "", Utf8);
                        qty.Append(Convert.ToInt32(Prop(it, "Qty")));
                        price.Append(Convert.ToInt64(Prop(it, "PriceMinor")));
                        total++;
                    }
                }
                offsets.Append(total);
            }
            var values = new StructArray(itemType, total,
                new IArrowArray[] { sku.Build(), qty.Build(), price.Build() }, ArrowBuffer.Empty, 0, 0);
            return new ListArray(new ListType(FieldOf("item", itemType)), rows.Count, offsets.Build(),
                values, ArrowBuffer.Empty, 0, 0);
        }

        static ListArray BuildLegs(IList rows, StructType legType)
        {
            var id = new Int64Array.Builder();
            var qty = new Int32Array.Builder();
            var pad = new Int32Array.Builder();
            var offsets = new ArrowBuffer.Builder<int>(rows.Count + 1);
            offsets.Append(0);
            int total = 0;
            for (int i = 0; i < rows.Count; i++)
            {
                var legs = Prop(rows[i], "Legs") as IList;
                if (legs != null)
                {
                    foreach (var leg in legs)
                    {
                        id.Append(Convert.ToInt64(Prop(leg, "LegId")));
                        qty.Append(Convert.ToInt32(Prop(leg, "LegQty")));
                        pad.Append(Convert.ToInt32(Prop(leg, "LegPad")));
                        total++;
                    }
                }
                offsets.Append(total);
            }
            var values = new StructArray(legType, total,
                new IArrowArray[] { id.Build(), qty.Build(), pad.Build() }, ArrowBuffer.Empty, 0, 0);
            return new ListArray(new ListType(FieldOf("item", legType)), rows.Count, offsets.Build(),
                values, ArrowBuffer.Empty, 0, 0);
        }

        static object ReadValue(Type target, Field field, IArrowArray array, int index)
        {
            if (array is DoubleArray doubles)
                return doubles.Values[index];
            if (array is Int64Array i64)
            {
                long v = i64.Values[index];
                // Separate returns: a ternary with long unifies to long and boxes Int64.
                if (target == typeof(int)) return (int)v;
                if (target == typeof(short)) return (short)v;
                return v;
            }
            if (array is Int32Array i32)
            {
                int v = i32.Values[index];
                if (target == typeof(long)) return (long)v;
                if (target == typeof(short)) return (short)v;
                return v;
            }
            if (array is StringArray str)
                return str.GetString(index, Utf8) ?? "";
            if (array is StructArray st)
            {
                var obj = Activator.CreateInstance(target);
                var stType = (StructType)field.DataType;
                for (int c = 0; c < st.Fields.Count; c++)
                {
                    var child = stType.GetFieldByIndex(c);
                    var prop = target.GetProperty(child.Name)
                        ?? throw new InvalidOperationException("struct field " + child.Name);
                    prop.SetValue(obj, ReadValue(prop.PropertyType, child, st.Fields[c], index));
                }
                return obj;
            }
            if (array is ListArray list)
            {
                var elem = target.GetGenericArguments()[0];
                var built = (IList)Activator.CreateInstance(typeof(List<>).MakeGenericType(elem));
                int len = list.GetValueLength(index);
                if (len == 0)
                    return built;
                var sliced = list.GetSlicedValues(index);
                var valueField = ((ListType)field.DataType).ValueField;
                for (int i = 0; i < len; i++)
                    built.Add(ReadValue(elem, valueField, sliced, i));
                return built;
            }
            throw new NotSupportedException("arrow array " + array.GetType().Name);
        }

        /// <summary>
        /// Read FFloat0 from the IPC body. Does not construct the other columns.
        /// </summary>
        static List<double> ProjectFFloat0(byte[] ipc)
        {
            var span = ipc.AsSpan();
            int pos = 0;
            string field0 = null;
            var list = new List<double>();
            var sawBatch = false;
            while (pos + 4 <= span.Length)
            {
                int first = ReadI32(span, pos);
                int metaLen;
                int metaStart;
                if (first == -1)
                {
                    if (pos + 8 > span.Length) break;
                    metaLen = ReadI32(span, pos + 4);
                    metaStart = pos + 8;
                }
                else
                {
                    metaLen = first;
                    metaStart = pos + 4;
                }
                if (metaLen <= 0) break;
                if (metaStart > span.Length || metaLen > span.Length - metaStart)
                    throw new InvalidOperationException("arrow-ipc metadata truncated");
                var meta = span.Slice(metaStart, metaLen);
                int root = ReadI32(meta, 0);
                int headerType = ReadU8(meta, root, 1);
                long bodyLen = ReadI64(meta, root, 3);
                int bodyStart = metaStart + metaLen;
                if (bodyLen < 0 || bodyStart > span.Length || bodyLen > span.Length - bodyStart)
                    throw new InvalidOperationException("arrow-ipc body truncated");
                if (headerType == 1)
                {
                    int schema = UnionTable(meta, root, 2);
                    field0 = SchemaFieldName(meta, schema, 0);
                }
                else if (headerType == 3)
                {
                    if (!string.Equals(field0, "FFloat0", StringComparison.Ordinal))
                        throw new InvalidOperationException("arrow-ipc field 0 is " + (field0 ?? "<missing>"));
                    int header = UnionTable(meta, root, 2);
                    // Flat table: field 0 validity is buffers[0], values are buffers[1].
                    int n = checked((int)NodeLength(meta, header, 0));
                    long off = BufferOffset(meta, header, 1);
                    var body = span.Slice(bodyStart, checked((int)bodyLen));
                    int start = checked((int)off);
                    int nbytes = n * sizeof(double);
                    if (start < 0 || nbytes < 0 || start > body.Length || nbytes > body.Length - start)
                        throw new InvalidOperationException(
                            $"arrow-ipc FFloat0 out of range n={n} off={off} body={body.Length}");
                    for (int i = 0; i < n; i++)
                        list.Add(BinaryPrimitives.ReadDoubleLittleEndian(body.Slice(start + i * 8, 8)));
                    sawBatch = true;
                }
                pos = bodyStart + checked((int)bodyLen);
            }
            if (!sawBatch)
                throw new InvalidOperationException("arrow-ipc stream has no record batch");
            return list;
        }

        static string SchemaFieldName(ReadOnlySpan<byte> meta, int schema, int fieldIndex)
        {
            int vec = Vector(meta, schema, 1);
            int count = ReadI32(meta, vec);
            if (fieldIndex < 0 || fieldIndex >= count)
                throw new InvalidOperationException("arrow-ipc schema field missing");
            int elem = vec + 4 + fieldIndex * 4;
            int field = elem + ReadI32(meta, elem);
            int rel = Slot(meta, field, 0);
            int namePos = field + rel;
            int str = namePos + ReadI32(meta, namePos);
            int len = ReadI32(meta, str);
            return Encoding.UTF8.GetString(meta.Slice(str + 4, len));
        }

        static int UnionTable(ReadOnlySpan<byte> buf, int table, int slot)
        {
            int rel = Slot(buf, table, slot);
            int pos = table + rel;
            return pos + ReadI32(buf, pos);
        }

        static byte ReadU8(ReadOnlySpan<byte> buf, int table, int slot)
        {
            int rel = Slot(buf, table, slot);
            if (rel == 0) return 0;
            return buf[table + rel];
        }

        static long ReadI64(ReadOnlySpan<byte> buf, int table, int slot)
        {
            int rel = Slot(buf, table, slot);
            // Absent scalar (schema bodyLength defaults to 0). Offset 0 is the vtable soffset, not the value.
            if (rel == 0) return 0;
            return BinaryPrimitives.ReadInt64LittleEndian(buf.Slice(table + rel, 8));
        }

        static long NodeLength(ReadOnlySpan<byte> meta, int recordBatch, int nodeIndex)
        {
            int vec = Vector(meta, recordBatch, 1);
            int count = ReadI32(meta, vec);
            if (nodeIndex < 0 || nodeIndex >= count)
                throw new InvalidOperationException("arrow-ipc field node missing");
            return BinaryPrimitives.ReadInt64LittleEndian(meta.Slice(vec + 4 + nodeIndex * 16, 8));
        }

        static long BufferOffset(ReadOnlySpan<byte> meta, int recordBatch, int bufferIndex)
        {
            int vec = Vector(meta, recordBatch, 2);
            int count = ReadI32(meta, vec);
            if (bufferIndex < 0 || bufferIndex >= count)
                throw new InvalidOperationException("arrow-ipc buffer missing");
            return BinaryPrimitives.ReadInt64LittleEndian(meta.Slice(vec + 4 + bufferIndex * 16, 8));
        }

        static int Vector(ReadOnlySpan<byte> buf, int table, int slot)
        {
            int rel = Slot(buf, table, slot);
            int pos = table + rel;
            return pos + ReadI32(buf, pos);
        }

        static int Slot(ReadOnlySpan<byte> buf, int table, int slot)
        {
            int vtRel = ReadI32(buf, table);
            int vt = table - vtRel;
            short vtLen = BinaryPrimitives.ReadInt16LittleEndian(buf.Slice(vt, 2));
            int entry = vt + 4 + slot * 2;
            if (entry + 2 > vt + vtLen) return 0;
            return BinaryPrimitives.ReadInt16LittleEndian(buf.Slice(entry, 2));
        }

        static int ReadI32(ReadOnlySpan<byte> buf, int pos) =>
            BinaryPrimitives.ReadInt32LittleEndian(buf.Slice(pos, 4));
    }
}
