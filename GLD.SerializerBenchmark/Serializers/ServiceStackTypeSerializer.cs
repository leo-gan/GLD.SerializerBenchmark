///
/// https://github.com/ServiceStack/ServiceStack.Text
/// PM> Install-Package ServiceStack.Text
/// TODO: DateTime fields is still under work.

using System.IO;
using ServiceStack.Text;

namespace GLD.SerializerBenchmark
{
    internal class ServiceStackTypeSerializer : ISerDeser
    {

        #region ISerDeser Members

        public string Name {get { return "ServiceStack Type"; } }

        public string Serialize<T>(object person)
        {
            using (var sw = new StringWriter())
            {
                TypeSerializer.SerializeToWriter<T>((T)person, sw);
                return sw.ToString();
            }
        }

        public T Deserialize<T>(string serialized)
        {
            using (var sr = new StringReader(serialized))
            {
                return TypeSerializer.DeserializeFromReader<T>(sr);
            }
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
                TypeSerializer.SerializeToWriter<T>((T)person, new StreamWriter(outputStream));
        }

  
        public T Deserialize<T>(Stream inputStream)
        {
                return TypeSerializer.DeserializeFromReader<T>(new StreamReader(inputStream));
        }

        #endregion
    }
}