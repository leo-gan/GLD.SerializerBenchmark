/// protobuf-net — RuntimeTypeModel compiled once; reuse MemoryStream for string mode.
using System.Collections.Generic;
/// https://github.com/protobuf-net/protobuf-net
using System;
using System.IO;
using ProtoBuf.Meta;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ProtoBufSerializer : SerDeser
    {
        private readonly RuntimeTypeModel _model = RuntimeTypeModel.Create();
        private readonly MemoryStream _serMs = new MemoryStream(4096);
        private bool _compiled;

        private void EnsureCompiled()
        {
            if (_compiled) return;
            _model.Add(_primaryType, true);
            if (_secondaryTypes != null)
            {
                foreach (var knownType in _secondaryTypes)
                    _model.Add(knownType, true);
            }
            _model.CompileInPlace();
            _compiled = true;
        }

        public override string Name => "ProtoBuf";

        // protobuf-net rejects System.Int32 as a model root (inbuilt).
        public override bool Supports(string testDataName) => testDataName != "Integer";

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _compiled = false;
            EnsureCompiled();
        }

        public override string Serialize(object serializable)
        {
            EnsureCompiled();
            _serMs.SetLength(0);
            _model.Serialize(_serMs, serializable);
            return Convert.ToBase64String(_serMs.GetBuffer(), 0, (int)_serMs.Length);
        }

        public override object Deserialize(string serialized)
        {
            EnsureCompiled();
            var b = Convert.FromBase64String(serialized);
            using var stream = new MemoryStream(b);
            return _model.Deserialize(stream, null, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            EnsureCompiled();
            _model.Serialize(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            EnsureCompiled();
            inputStream.Seek(0, SeekOrigin.Begin);
            return _model.Deserialize(inputStream, null, _primaryType);
        }
    }
}
