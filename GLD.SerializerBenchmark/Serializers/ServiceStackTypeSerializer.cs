///
/// https://github.com/ServiceStack/ServiceStack.Text
/// PM> Install-Package ServiceStack.Text
/// TODO: DateTime fields is still under work.

using System.IO;
using ServiceStack.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ServiceStackTypeSerializer : SerDeser
    {
        #region ISerDeser Members

        public override string Name
        {
            get { return "ServiceStack Type"; }
        }

        public override string Serialize(object serializable)
        {
            return TypeSerializer.SerializeToString(serializable, _primaryType);
        }

        public override object Deserialize(string serialized)
        {
            return TypeSerializer.DeserializeFromString(serialized, _primaryType);
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