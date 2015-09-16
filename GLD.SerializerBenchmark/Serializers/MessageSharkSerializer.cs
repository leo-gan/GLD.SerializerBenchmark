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

        public override string Name
        {
            get { return "MessageShark"; }
        }

        public override string Serialize(object serializable)
        {
            using (var ms = new MemoryStream())
            {
                MessageSharkSerializer.Serialize(_primaryType, serializable, ms);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public override object Deserialize(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return MessageSharkSerializer.Deserialize(_primaryType, stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            MessageSharkSerializer.Serialize(_primaryType, serializable, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            return MessageSharkSerializer.Deserialize(_primaryType, inputStream);
        }

        #endregion
    }
}