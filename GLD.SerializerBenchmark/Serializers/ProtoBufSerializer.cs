///
/// See here https://github.com/mgravell/protobuf-net
/// >PM Install-Package protobuf-net
///     NOTE: I use the protobuf-net NuGet package because of
///     [http://stackoverflow.com/questions/2522376/how-to-choose-between-protobuf-csharp-port-and-protobuf-net]
/// 

using System;
using System.IO;
using ProtoBuf.Meta;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ProtoBufSerializer : SerDeser
    {
        private readonly RuntimeTypeModel _Model = TypeModel.Create();

        private void Initialize()
        {
            if (_Model.GetTypes() != null) return;

            _Model.Add(_primaryType, true);
            foreach (var knownType in _secondaryTypes)
                _Model.Add(knownType, true);

            _Model.CompileInPlace();
        }

        #region ISerDeser Members

        public override string Name
        {
            get { return "ProtoBuf"; }
        }

        public override string Serialize(object serializable)
        {
            Initialize();
            var ms = new MemoryStream();
            _Model.Serialize(ms, serializable);
            ms.Flush();
            ms.Position = 0;
            return Convert.ToBase64String(ms.ToArray());
        }

        public override object Deserialize(string serialized)
        {
            Initialize();
            var b = Convert.FromBase64String(serialized);
            var stream = new MemoryStream(b);
            stream.Seek(0, SeekOrigin.Begin);
            return _Model.Deserialize(stream, null, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Initialize();
            _Model.Serialize(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            Initialize();
            inputStream.Seek(0, SeekOrigin.Begin);
            return _Model.Deserialize(inputStream, null, _primaryType);
        }

        #endregion
    }
}