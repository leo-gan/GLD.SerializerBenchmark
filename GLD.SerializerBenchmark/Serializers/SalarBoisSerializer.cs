///
/// See here https://github.com/salarcode/Bois
/// PM> Install-Package Salar.Bois
/// 

using System;
using System.IO;
using Salar.Bois;

namespace GLD.SerializerBenchmark
{
     internal class SalarBoisSerializer : ISerDeser
    {
        private static readonly BoisSerializer _serializer = new BoisSerializer();
            

        // TODO: Hack! How to get a type of the person object? In XmlSerializer it works, not here!

        //public MsgPackSerializer (Person t)
        //{
        //    var _serializer = MsgPack.Serialization.SerializationContext.Default.GetSerializer<Person>();
        //}

        #region ISerDeser Members

        public string Name {get { return "Salar.Bois"; } }

         public string Serialize<T>(object person)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize((T)person, ms);
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
                return (T) _serializer.Deserialize<T>(stream);
            }
        }

        #endregion
    }
}