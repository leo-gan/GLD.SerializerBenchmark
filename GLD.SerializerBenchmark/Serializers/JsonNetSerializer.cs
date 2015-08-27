using System.IO;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JsonNetSerializer : SerDeser
    {
        private readonly JsonSerializer _serializer = new JsonSerializer();

        #region ISerDeser Members

        public override string Name
        {
            get { return "Json.Net"; }
        }

        public override string Serialize(object serializable)
        {
           using (var sw = new StringWriter())
            using (var jw = new JsonTextWriter(sw))
            {
                _serializer.Serialize(jw, serializable);
                return sw.ToString();
            }
        }

        public override object Deserialize(string serialized)
        {
            using (var sr = new StringReader(serialized))
            using (var jr = new JsonTextReader(sr))
            {
                return _serializer.Deserialize(jr, _primaryType);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var sw = new StreamWriter(outputStream);
            var jw = new JsonTextWriter(sw);
            _serializer.Serialize(jw, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            //inputStream.Position = 0;
            var sr = new StreamReader(inputStream);
            var jr = new JsonTextReader(sr);
            return _serializer.Deserialize(jr, _primaryType);
        }
        #endregion
    }
}