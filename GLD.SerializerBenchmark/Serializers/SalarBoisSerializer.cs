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

         public void Serialize<T>(object person, Stream outputStream)
         {
                _serializer.Serialize((T)person, outputStream);
         }

 
         public T Deserialize<T>(Stream inputStream)
         {
                return (T) _serializer.Deserialize<T>(inputStream);
         }

         #endregion
    }
}