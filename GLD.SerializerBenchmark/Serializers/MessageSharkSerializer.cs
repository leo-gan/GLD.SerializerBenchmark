///
/// See here https://github.com/rpgmaker/MessageShark
/// >PM Install-Package MessageShark
/// 

using System;
using MessageShark;

namespace GLD.SerializerBenchmark
{
    internal class MessageSharkSer : ISerDeser
    {
        #region ISerDeser Members

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

        #endregion
    }
}