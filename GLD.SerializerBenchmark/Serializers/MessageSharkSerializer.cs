///
/// See here https://github.com/rpgmaker/MessageShark
/// >PM Install-Package MessageShark
/// 

using System;
using System.IO;
using MessageShark;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class MessageSharkSer : SerDeser
    {
        #region ISerDeser Members

        public override string Name {get { return "MessageShark"; } }
        public override string Serialize(object serializable)
        {
            var buf = MessageSharkSerializer.Serialize(serializable);
            return Convert.ToBase64String(buf);
        }

        public override object Deserialize(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            return MessageSharkSerializer.Deserialize<object>(b);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            MessageSharkSerializer.Serialize(serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            using (var ms = new MemoryStream())
            {
                inputStream.CopyTo(ms);
                return MessageSharkSerializer.Deserialize<object>(ms.ToArray());
            }
        }
        #endregion
    }
}