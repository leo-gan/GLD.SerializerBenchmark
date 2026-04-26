using System.IO;
using ServiceStack.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ServiceStackJsonSerializer : SerDeser
    {
        #region ISerDeser Members

        public override string Name
        {
            get { return "ServiceStack Json"; }
        }

        public override bool Supports(string testDataName)
        {
            // ServiceStack Json can have issues with circular references in some versions
            return testDataName != "ObjectGraph";
        }

        public override string Serialize(object serializable)
        {
            return JsonSerializer.SerializeToString(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return JsonSerializer.DeserializeFromString(serialized, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            JsonSerializer.SerializeToStream(serializable, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return JsonSerializer.DeserializeFromStream(_primaryType, inputStream);
        }

        #endregion
    }
}