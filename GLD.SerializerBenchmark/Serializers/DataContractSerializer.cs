///
/// using System.Runtime.Serialization
/// 

using System;
using System.IO;
using System.Runtime.Serialization;

namespace GLD.SerializerBenchmark
{
    internal class DataContractSerializerSerializer : ISerDeser
    {
        private static  DataContractSerializer _serializer = null;


        public DataContractSerializerSerializer(Type t, Type[] extraTypes)
        {
            _serializer = new DataContractSerializer(t, extraTypes);
        }

        #region ISerDeser Members

        public string Name {get { return "MS DataContract"; } }

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