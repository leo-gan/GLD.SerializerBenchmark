///
/// See here https://www.nuget.org/packages/HaveBoxJSONSer/
/// >PM Install-Package HaveBoxJSON
/// 

using System.IO;
using HaveBoxJSON;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class HaveBoxJSONSerializer : SerDeser
    {
        private static readonly JsonConverter _serializer = new JsonConverter();

        #region ISerDeser Members

        public override string Name {get { return "HaveBoxJSONSer"; } }
        public override string Serialize(object serializable)
        {
            return _serializer.Serialize(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return _serializer.Deserialize(_primaryType, serialized);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            throw new System.NotImplementedException();
        }

        public override object Deserialize(Stream inputStream)
        {
            throw new System.NotImplementedException();
        }
        #endregion
    }
}