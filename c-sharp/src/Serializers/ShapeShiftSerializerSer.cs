using System;
using System.IO;
using System.Reflection;
using System.Text;
using PolyType;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Provides the common bridge from ShapeShift's source-generated typed APIs to the suite's object API.
    /// </summary>
    internal abstract class ShapeShiftSerializerSer : SerDeser
    {
        private static readonly MethodInfo ConfigureMethod = typeof(ShapeShiftSerializerSer)
            .GetMethod(nameof(Configure), BindingFlags.Instance | BindingFlags.NonPublic);

        public override void Initialize(Type serializablePrimaryType, System.Collections.Generic.List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            ConfigureMethod.MakeGenericMethod(serializablePrimaryType).Invoke(this, null);
        }

        /// <summary>
        /// Builds typed delegates once per fixture so the measured path does not use reflection.
        /// </summary>
        /// <typeparam name="T">The generated ShapeShift contract type.</typeparam>
        private void Configure<T>()
            where T : IShapeable<T> => this.ConfigureTyped<T>();

        /// <summary>
        /// Configures the serializer-specific typed delegates.
        /// </summary>
        /// <typeparam name="T">The generated ShapeShift contract type.</typeparam>
        protected abstract void ConfigureTyped<T>()
            where T : IShapeable<T>;
    }

    /// <summary>
    /// Bridges a ShapeShift text serializer to the suite's string and stream paths.
    /// </summary>
    internal abstract class ShapeShiftTextSerializerSer : ShapeShiftSerializerSer
    {
        private Func<object, string> serialize;
        private Func<string, object> deserialize;
        private Action<object, Stream> serializeToStream;
        private Func<Stream, object> deserializeFromStream;

        public override string StreamMode => this.serializeToStream is null ? "text_on_stream" : "native";

        public override string Serialize(object serializable) => serialize(serializable);

        public override object Deserialize(string serialized) => deserialize(serialized);

        public override void Serialize(object serializable, Stream outputStream)
        {
            if (this.serializeToStream is not null)
            {
                this.serializeToStream(serializable, outputStream);
                return;
            }

            using var writer = new StreamWriter(outputStream, new UTF8Encoding(false), 1024, true);
            writer.Write(serialize(serializable));
        }

        public override object Deserialize(Stream inputStream)
        {
            if (this.deserializeFromStream is not null)
            {
                inputStream.Seek(0, SeekOrigin.Begin);
                return this.deserializeFromStream(inputStream);
            }

            inputStream.Seek(0, SeekOrigin.Begin);
            using var reader = new StreamReader(inputStream, Encoding.UTF8, true, 1024, true);
            return deserialize(reader.ReadToEnd());
        }

        protected override void ConfigureTyped<T>()
        {
            serialize = value => this.SerializeTyped((T)value);
            deserialize = value => this.DeserializeTyped<T>(value);
        }

        protected void ConfigureNativeStream<T>(
            Action<T, Stream> serialize,
            Func<Stream, T> deserialize)
            where T : IShapeable<T>
        {
            this.serializeToStream = (value, stream) => serialize((T)value, stream);
            this.deserializeFromStream = stream => deserialize(stream);
        }

        protected abstract string SerializeTyped<T>(T value)
            where T : IShapeable<T>;

        protected abstract T DeserializeTyped<T>(string value)
            where T : IShapeable<T>;
    }

    /// <summary>
    /// Bridges a ShapeShift binary serializer to the suite's Base64 string and stream paths.
    /// </summary>
    internal abstract class ShapeShiftBinarySerializerSer : ShapeShiftSerializerSer
    {
        private Func<object, byte[]> serialize;
        private Func<byte[], object> deserialize;
        private Action<object, Stream> serializeToStream;
        private Func<Stream, object> deserializeFromStream;

        public override string StreamMode => this.serializeToStream is null ? "adapted" : "native";

        public override string Serialize(object serializable) => Convert.ToBase64String(serialize(serializable));

        public override object Deserialize(string serialized) => deserialize(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            if (this.serializeToStream is not null)
            {
                this.serializeToStream(serializable, outputStream);
                return;
            }

            byte[] bytes = serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            if (this.deserializeFromStream is not null)
            {
                inputStream.Seek(0, SeekOrigin.Begin);
                return this.deserializeFromStream(inputStream);
            }

            inputStream.Seek(0, SeekOrigin.Begin);
            using var output = new MemoryStream();
            inputStream.CopyTo(output);
            return deserialize(output.ToArray());
        }

        protected override void ConfigureTyped<T>()
        {
            serialize = value => this.SerializeTyped((T)value);
            deserialize = value => this.DeserializeTyped<T>(value);
        }

        protected void ConfigureNativeStream<T>(
            Action<T, Stream> serialize,
            Func<Stream, T> deserialize)
            where T : IShapeable<T>
        {
            this.serializeToStream = (value, stream) => serialize((T)value, stream);
            this.deserializeFromStream = stream => deserialize(stream);
        }

        protected abstract byte[] SerializeTyped<T>(T value)
            where T : IShapeable<T>;

        protected abstract T DeserializeTyped<T>(byte[] value)
            where T : IShapeable<T>;
    }

    /// <summary>
    /// Benchmarks ShapeShift's JSON serializer.
    /// </summary>
    internal sealed class ShapeShiftJsonSerializerSer : ShapeShiftTextSerializerSer
    {
        private readonly ShapeShift.Json.JsonSerializer serializer = new ShapeShift.Json.JsonSerializer();

        public override string Name => "ShapeShift.Json";

        protected override string SerializeTyped<T>(T value) => serializer.Serialize(value);

        protected override T DeserializeTyped<T>(string value) => serializer.Deserialize<T>(value);

        protected override void ConfigureTyped<T>()
        {
            base.ConfigureTyped<T>();
            this.ConfigureNativeStream<T>(
                (value, stream) => serializer.SerializeAsync(stream, value).GetAwaiter().GetResult(),
                stream => serializer.DeserializeAsync<T>(stream).GetAwaiter().GetResult());
        }
    }

    /// <summary>
    /// Benchmarks ShapeShift's TAML serializer.
    /// </summary>
    internal sealed class ShapeShiftTamlSerializerSer : ShapeShiftTextSerializerSer
    {
        private readonly ShapeShift.Taml.TamlSerializer serializer = new ShapeShift.Taml.TamlSerializer();

        public override string Name => "ShapeShift.Taml";

        public override bool Supports(string testDataName) => testDataName != "strings";

        protected override string SerializeTyped<T>(T value) => serializer.Serialize(value);

        protected override T DeserializeTyped<T>(string value) => serializer.Deserialize<T>(value);
    }

    /// <summary>
    /// Benchmarks ShapeShift's TOML serializer.
    /// </summary>
    internal sealed class ShapeShiftTomlSerializerSer : ShapeShiftTextSerializerSer
    {
        private readonly ShapeShift.Toml.TomlSerializer serializer = new ShapeShift.Toml.TomlSerializer();

        public override string Name => "ShapeShift.Toml";

        protected override string SerializeTyped<T>(T value) => serializer.Serialize(value);

        protected override T DeserializeTyped<T>(string value) => serializer.Deserialize<T>(value);
    }

    /// <summary>
    /// Benchmarks ShapeShift's YAML serializer.
    /// </summary>
    internal sealed class ShapeShiftYamlSerializerSer : ShapeShiftTextSerializerSer
    {
        private readonly ShapeShift.Yaml.YamlSerializer serializer = new ShapeShift.Yaml.YamlSerializer();

        public override string Name => "ShapeShift.Yaml";

        protected override string SerializeTyped<T>(T value) => serializer.Serialize(value);

        protected override T DeserializeTyped<T>(string value) => serializer.Deserialize<T>(value);
    }

    /// <summary>
    /// Benchmarks ShapeShift's CBOR serializer.
    /// </summary>
    internal sealed class ShapeShiftCborSerializerSer : ShapeShiftBinarySerializerSer
    {
        private readonly ShapeShift.Cbor.CborSerializer serializer = new ShapeShift.Cbor.CborSerializer();

        public override string Name => "ShapeShift.Cbor";

        protected override byte[] SerializeTyped<T>(T value) => serializer.Serialize(value);

        protected override T DeserializeTyped<T>(byte[] value) => serializer.Deserialize<T>(value);
    }

    /// <summary>
    /// Benchmarks ShapeShift's MessagePack serializer.
    /// </summary>
    internal sealed class ShapeShiftMsgPackSerializerSer : ShapeShiftBinarySerializerSer
    {
        private readonly ShapeShift.MsgPack.MsgPackSerializer serializer = new ShapeShift.MsgPack.MsgPackSerializer();

        public override string Name => "ShapeShift.MsgPack";

        protected override byte[] SerializeTyped<T>(T value) => serializer.Serialize(value);

        protected override T DeserializeTyped<T>(byte[] value) => serializer.Deserialize<T>(value);

        protected override void ConfigureTyped<T>()
        {
            base.ConfigureTyped<T>();
            this.ConfigureNativeStream<T>(
                (value, stream) => serializer.SerializeAsync(stream, value).GetAwaiter().GetResult(),
                stream => serializer.DeserializeAsync<T>(stream).GetAwaiter().GetResult());
        }
    }

    /// <summary>
    /// Benchmarks ShapeShift's Protocol Buffers-style serializer.
    /// </summary>
    internal sealed class ShapeShiftProtobufSerializerSer : ShapeShiftBinarySerializerSer
    {
        private readonly ShapeShift.Protobuf.ProtobufSerializer serializer = new ShapeShift.Protobuf.ProtobufSerializer();

        public override string Name => "ShapeShift.Protobuf";

        protected override byte[] SerializeTyped<T>(T value) => serializer.Serialize(value);

        protected override T DeserializeTyped<T>(byte[] value) => serializer.Deserialize<T>(value);
    }
}
