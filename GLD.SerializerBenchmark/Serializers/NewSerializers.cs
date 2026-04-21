using System;
using System.IO;
using System.Collections.Generic;
using System.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    // Ceras
    internal class CerasSerializerSer : SerDeser
    {
        private static readonly Lazy<Ceras.CerasSerializer> _serializer = new Lazy<Ceras.CerasSerializer>(() => new Ceras.CerasSerializer());
        public override string Name => "Ceras";
        public override string Serialize(object serializable) => Convert.ToBase64String(_serializer.Value.Serialize(serializable));
        public override object Deserialize(string serialized) {
            var bytes = Convert.FromBase64String(serialized);
            return _serializer.Value.Deserialize<object>(bytes);
        }
        public override void Serialize(object serializable, Stream outputStream) {
            var bytes = _serializer.Value.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }
        public override object Deserialize(Stream inputStream) {
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return _serializer.Value.Deserialize<object>(ms.ToArray());
        }
    }





    // Hyperion
    internal class HyperionSerializerSer : SerDeser
    {
        private static readonly Hyperion.Serializer _serializer = new Hyperion.Serializer(new Hyperion.SerializerOptions());
        public override string Name => "Hyperion";
        public override string Serialize(object serializable) {
            using var ms = new MemoryStream();
            _serializer.Serialize(serializable, ms);
            return Convert.ToBase64String(ms.ToArray());
        }
        public override object Deserialize(string serialized) {
            using var ms = new MemoryStream(Convert.FromBase64String(serialized));
            return _serializer.Deserialize<object>(ms);
        }
        public override void Serialize(object serializable, Stream outputStream) {
            _serializer.Serialize(serializable, outputStream);
        }
        public override object Deserialize(Stream inputStream) {
            return _serializer.Deserialize<object>(inputStream);
        }
    }

    // SharpYaml
    internal class SharpYamlSerializerSer : SerDeser
    {
        public override string Name => "SharpYaml";
        public override string Serialize(object serializable) => SharpYaml.YamlSerializer.Serialize(serializable);
        public override object Deserialize(string serialized) => SharpYaml.YamlSerializer.Deserialize<object>(serialized);
        public override void Serialize(object serializable, Stream outputStream) {
            using var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            sw.Write(SharpYaml.YamlSerializer.Serialize(serializable));
        }
        public override object Deserialize(Stream inputStream) {
            using var sr = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true);
            return SharpYaml.YamlSerializer.Deserialize<object>(sr.ReadToEnd());
        }
    }

    // YamlDotNet
    internal class YamlDotNetSerializerSer : SerDeser
    {
        private static readonly YamlDotNet.Serialization.ISerializer _serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
        private static readonly YamlDotNet.Serialization.IDeserializer _deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
        public override string Name => "YamlDotNet";
        public override string Serialize(object serializable) => _serializer.Serialize(serializable);
        public override object Deserialize(string serialized) => _deserializer.Deserialize(new StringReader(serialized));
        public override void Serialize(object serializable, Stream outputStream) {
            using var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            _serializer.Serialize(sw, serializable);
        }
        public override object Deserialize(Stream inputStream) {
            using var sr = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true);
            return _deserializer.Deserialize(sr);
        }
    }

    // Utf8Json
    internal class Utf8JsonSerializerSer : SerDeser
    {
        public override string Name => "Utf8Json";
        public override string Serialize(object serializable) => Utf8Json.JsonSerializer.ToJsonString(serializable);
        public override object Deserialize(string serialized) => Utf8Json.JsonSerializer.Deserialize<dynamic>(serialized);
        public override void Serialize(object serializable, Stream outputStream) {
            Utf8Json.JsonSerializer.Serialize(outputStream, serializable);
        }
        public override object Deserialize(Stream inputStream) {
            return Utf8Json.JsonSerializer.Deserialize<dynamic>(inputStream);
        }
    }

    // SpanJson
    internal class SpanJsonSerializerSer : SerDeser
    {
        public override string Name => "SpanJson";
        public override string Serialize(object serializable) => SpanJson.JsonSerializer.Generic.Utf16.Serialize(serializable);
        public override object Deserialize(string serialized) => SpanJson.JsonSerializer.Generic.Utf16.Deserialize<object>(serialized);
        public override void Serialize(object serializable, Stream outputStream) {
            using var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            sw.Write(SpanJson.JsonSerializer.Generic.Utf16.Serialize(serializable));
        }
        public override object Deserialize(Stream inputStream) {
            using var sr = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true);
            return SpanJson.JsonSerializer.Generic.Utf16.Deserialize<object>(sr.ReadToEnd());
        }
    }

    // YAXLib
    internal class YAXLibSerializerSer : SerDeser
    {
        public override string Name => "YAXLib";
        public override string Serialize(object serializable) {
            var serializer = new YAXLib.YAXSerializer(serializable.GetType());
            return serializer.Serialize(serializable);
        }
        public override object Deserialize(string serialized) {
            return null; // YAXLib requires generic type, hard to do `object`
        }
        public override void Serialize(object serializable, Stream outputStream) {
            var serializer = new YAXLib.YAXSerializer(serializable.GetType());
            using var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            serializer.Serialize(serializable, sw);
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }

    // ZeroFormatter
    internal class ZeroFormatterSerializerSer : SerDeser
    {
        public override string Name => "ZeroFormatter";
        public override string Serialize(object serializable) => Convert.ToBase64String(ZeroFormatter.ZeroFormatterSerializer.Serialize(serializable));
        public override object Deserialize(string serialized) => ZeroFormatter.ZeroFormatterSerializer.Deserialize<object>(Convert.FromBase64String(serialized));
        public override void Serialize(object serializable, Stream outputStream) {
            var bytes = ZeroFormatter.ZeroFormatterSerializer.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }
        public override object Deserialize(Stream inputStream) {
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return ZeroFormatter.ZeroFormatterSerializer.Deserialize<object>(ms.ToArray());
        }
    }

    // BinaryPack
    internal class BinaryPackSerializerSer : SerDeser
    {
        public override string Name => "BinaryPack";
        public override string Serialize(object serializable) => Convert.ToBase64String(BinaryPack.BinaryConverter.Serialize(serializable));
        public override object Deserialize(string serialized) => BinaryPack.BinaryConverter.Deserialize<object>(Convert.FromBase64String(serialized));
        public override void Serialize(object serializable, Stream outputStream) {
            var bytes = BinaryPack.BinaryConverter.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }
        public override object Deserialize(Stream inputStream) {
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return BinaryPack.BinaryConverter.Deserialize<object>(ms.ToArray());
        }
    }

    // MemoryPack
    internal class MemoryPackSerializerSer : SerDeser
    {
        public override string Name => "MemoryPack";
        public override string Serialize(object serializable) => Convert.ToBase64String(MemoryPack.MemoryPackSerializer.Serialize(serializable));
        public override object Deserialize(string serialized) => MemoryPack.MemoryPackSerializer.Deserialize<object>(Convert.FromBase64String(serialized));
        public override void Serialize(object serializable, Stream outputStream) {
            var bytes = MemoryPack.MemoryPackSerializer.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }
        public override object Deserialize(Stream inputStream) {
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return MemoryPack.MemoryPackSerializer.Deserialize<object>(ms.ToArray());
        }
    }


}
