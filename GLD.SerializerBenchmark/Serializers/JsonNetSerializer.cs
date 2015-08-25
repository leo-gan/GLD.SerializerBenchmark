using System.IO;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark
{
    internal class JsonNetSerializer : ISerDeser
    {
        private readonly JsonSerializer _serializer = new JsonSerializer();

        #region ISerDeser Members

        public string Name
        {
            get { return "Json.Net"; }
        }

        public string Serialize<T>(object person)
        {
            using (var sw = new StringWriter())
            using (var jw = new JsonTextWriter(sw))
            {
                _serializer.Serialize(jw, (T) person);
                return sw.ToString();
            }
        }

        public T Deserialize<T>(string serialized)
        {
            using (var sr = new StringReader(serialized))
            using (var jr = new JsonTextReader(sr))
            {
                return _serializer.Deserialize<T>(jr);
            }
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
            var sw = new StreamWriter(outputStream);
            var jw = new JsonTextWriter(sw);
            _serializer.Serialize(jw, (T) person);
        }


        public T Deserialize<T>(Stream inputStream)
        {
            inputStream.Position = 0;
            var sr = new StreamReader(inputStream);
            var jr = new JsonTextReader(sr);
            return _serializer.Deserialize<T>(jr);
        }

        #endregion
    }
}