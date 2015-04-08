///
/// /// System.Runtime.Serialization.dll 
/// 

using System;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal class NetDataContractSerializer : ISerDeser
    {
        private static  System.Runtime.Serialization.DataContractSerializer _serializer = null;


        public NetDataContractSerializer(Type t)
        {
            _serializer = new System.Runtime.Serialization.DataContractSerializer(t);
        }

        #region ISerDeser Members

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

        #endregion
    }
}