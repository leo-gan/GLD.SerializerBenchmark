using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using Parquet;
using Parquet.Schema;
using Parquet.Serialization;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Parquet.Net row group. <c>parquet</c> uses the library default (Snappy).
    /// <c>parquet-uncompressed</c> sets <see cref="CompressionMethod.None"/>.
    /// String path is Base64. Stream path writes the same bytes (adapted).
    /// table_project reads the FFloat0 data field only.
    /// </summary>
    internal sealed class ParquetColumnarSerializerSer : SerDeser
    {
        readonly bool _uncompressed;
        bool _batch;
        Type _rowType;
        PropertyInfo _itemsProp;
        MethodInfo _serialize;
        MethodInfo _deserialize;

        public ParquetColumnarSerializerSer(bool uncompressed) => _uncompressed = uncompressed;

        public override string Name => _uncompressed ? "parquet-uncompressed" : "parquet";

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

            _serialize = typeof(ParquetSerializer).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "SerializeAsync" && m.IsGenericMethodDefinition
                    && m.GetParameters().Length >= 2
                    && m.GetParameters()[1].ParameterType == typeof(Stream))
                .MakeGenericMethod(_rowType);
            _deserialize = typeof(ParquetSerializer).GetMethods(BindingFlags.Public | BindingFlags.Static)
                .First(m => m.Name == "DeserializeAsync" && m.IsGenericMethodDefinition
                    && m.GetParameters()[0].ParameterType == typeof(Stream))
                .MakeGenericMethod(_rowType);
        }

        public override string Serialize(object serializable)
            => Convert.ToBase64String(Encode(serializable));

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return IsTableProject ? Project(bytes) : Decode(bytes);
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
            return IsTableProject ? Project(bytes) : Decode(bytes);
        }

        ParquetOptions WriteOptions() => _uncompressed
            ? new ParquetOptions { CompressionMethod = CompressionMethod.None }
            : null;

        byte[] Encode(object data)
        {
            var rows = TypedRows(data);
            var ms = new MemoryStream();
            Wait((Task)_serialize.Invoke(null, new[] { rows, ms, WriteOptions(), null, CancellationToken.None }));
            return ms.ToArray();
        }

        object Decode(byte[] bytes)
        {
            var ms = new MemoryStream(bytes);
            var task = (Task)_deserialize.Invoke(null, new object[] { ms, null, null, CancellationToken.None });
            Wait(task);
            var result = task.GetType().GetProperty("Result").GetValue(task);
            var data = (IList)result.GetType().GetProperty("Data").GetValue(result);
            if (!_batch)
                return data.Count == 0 ? Activator.CreateInstance(_rowType) : data[0];
            var list = (IList)Activator.CreateInstance(typeof(List<>).MakeGenericType(_rowType));
            foreach (var row in data)
                list.Add(row);
            var wrapped = Activator.CreateInstance(_primaryType);
            _itemsProp.SetValue(wrapped, list);
            return wrapped;
        }

        List<double> Project(byte[] bytes)
        {
            var ms = new MemoryStream(bytes);
            var reader = ParquetReader.CreateAsync(ms, null, leaveStreamOpen: true).GetAwaiter().GetResult();
            try
            {
                var field = reader.Schema.FindDataField("FFloat0");
                if (field == null)
                {
                    var names = string.Join(",", reader.Schema.GetDataFields().Select(f => f.Name));
                    throw new InvalidOperationException("parquet FFloat0 missing: " + names);
                }
                using var rg = reader.OpenRowGroupReader(0);
                int n = checked((int)rg.RowCount);
                var dest = new double[n];
                rg.ReadAsync(field, dest.AsMemory()).GetAwaiter().GetResult();
                return new List<double>(dest);
            }
            finally
            {
                reader.DisposeAsync().AsTask().GetAwaiter().GetResult();
            }
        }

        object TypedRows(object data)
        {
            var list = (IList)Activator.CreateInstance(typeof(List<>).MakeGenericType(_rowType));
            if (_batch)
            {
                foreach (var item in (IEnumerable)_itemsProp.GetValue(data))
                    list.Add(item);
            }
            else
            {
                list.Add(data);
            }
            return list;
        }

        static void Wait(Task task)
        {
            try
            {
                task.GetAwaiter().GetResult();
            }
            catch (TargetInvocationException ex) when (ex.InnerException != null)
            {
                throw ex.InnerException;
            }
        }
    }
}
