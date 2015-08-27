///
/// https://github.com/ServiceStack/ServiceStack.Text
/// PM> Install-Package ServiceStack.Text
/// TODO: DateTime fields is still under work.

using System.IO;
using ServiceStack.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ServiceStackJsonSerializer : SerDeser
    {

        #region ISerDeser Members

        public override string Name {get { return "ServiceStack Json"; } }
        public override string Serialize(object serializable)
        {
               return JsonSerializer.SerializeToString(serializable, _primaryType);
        }

        public override object Deserialize(string serialized)
        {
                return JsonSerializer.DeserializeFromString(serialized, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
                JsonSerializer.SerializeToStream(serializable, _primaryType, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
                return JsonSerializer.DeserializeFromStream(_primaryType, inputStream);
        }
        #endregion
    }
}