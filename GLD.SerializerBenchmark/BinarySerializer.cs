using System;
using System.IO;
using System.Runtime.Serialization.Formatters.Binary;

namespace GLD.SerializerBenchmark
{
    internal class BinarySerializer : ISerDeser
    {
        private readonly BinaryFormatter _formatter = new BinaryFormatter();

        #region ISerDeser Members

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
            byte[] b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                var formatter = new BinaryFormatter();
                stream.Seek(0, SeekOrigin.Begin);
                return (T) formatter.Deserialize(stream);
            }
        }

        #endregion
    }
}