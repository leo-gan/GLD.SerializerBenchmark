///
/// https://github.com/ServiceStack/ServiceStack.Text
/// PM> Install-Package ServiceStack.Text

using System.IO;
using ServiceStack.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ServiceStackTypeSerializer : SerDeser
    {
        #region ISerDeser Members

        public override string Name
        {
            get { return "ServiceStack"; }
        }

        public override byte[] SerializeBytes(object serializable)
        {
            return Utf8Bytes(TypeSerializer.SerializeToString(serializable, _primaryType));
        }

        public override object DeserializeBytes(byte[] serialized)
        {
            return TypeSerializer.DeserializeFromString(Utf8Text(serialized), _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            TypeSerializer.SerializeToStream(serializable, _primaryType, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return TypeSerializer.DeserializeFromStream(_primaryType, inputStream);
        }

        #endregion
    }
}