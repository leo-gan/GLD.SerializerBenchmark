///
/// See here https://github.com/rpgmaker/MessageShark
/// >PM Install-Package MessageShark
/// 

using System;
using System.IO;
using MessageShark;

namespace GLD.SerializerBenchmark
{
    internal class MessageSharkSer : ISerDeser
    {
        #region ISerDeser Members

        public string Name {get { return "MessageShark"; } }

        public string Serialize<T>(object person)
        {
            var buf = MessageSharkSerializer.Serialize((T) person);
            return Convert.ToBase64String(buf);
        }

        public T Deserialize<T>(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            return MessageSharkSerializer.Deserialize<T>(b);
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
            MessageSharkSerializer.Serialize((T) person);
        }


        public T Deserialize<T>(Stream inputStream)
        {
            using (var ms = new MemoryStream())
            {
                inputStream.CopyTo(ms);
                return MessageSharkSerializer.Deserialize<T>(ms.ToArray());
            }
        }

        #endregion
    }
}