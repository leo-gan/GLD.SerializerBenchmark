using System;
using System.IO;
using System.Runtime.Serialization.Formatters.Binary;

namespace GLD.SerializerBenchmark
{
    internal class BinarySerializer : ISerDeser
    {
        private readonly BinaryFormatter _formatter = new BinaryFormatter();

        #region ISerDeser Members

        public string Name {get { return "MS Binary"; } }

        public string Serialize<T>(object person)
        {
            using (var ms = new MemoryStream())
            {
                _formatter.Serialize(ms, (T)person);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public T Deserialize<T>(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return (T) _formatter.Deserialize(stream);
            }
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
                _formatter.Serialize(outputStream, (T)person);
        }

  
        public T Deserialize<T>(Stream inputStream)
        {
                return (T) _formatter.Deserialize(inputStream);
        }

        #endregion
    }
}