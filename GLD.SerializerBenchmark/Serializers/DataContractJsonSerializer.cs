///
/// System.Runtime.Serialization.dll 
/// 

using System;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal class DataContractJsonSerializer : ISerDeser
    {
        private static  System.Runtime.Serialization.Json.DataContractJsonSerializer _serializer = null;


        public DataContractJsonSerializer(Type t, Type[] extraTypes)
        {
            _serializer = new System.Runtime.Serialization.Json.DataContractJsonSerializer(t, extraTypes);
        }

        #region ISerDeser Members

        public string Name {get { return "MS DataContract Json"; } }

        public string Serialize<T>(object person)
        {
            using (var stream = new MemoryStream())
            {
                _serializer.WriteObject(stream, (T)person);
                stream.Flush();
                stream.Position = 0;
                return Convert.ToBase64String(stream.ToArray());
            }
        }

        public T Deserialize<T>(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return (T) _serializer.ReadObject(stream);
            }
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
                _serializer.WriteObject(outputStream, (T)person);
        }

  
        public T Deserialize<T>(Stream inputStream)
        {
                return (T) _serializer.ReadObject(inputStream);
        }

        #endregion
    }
}