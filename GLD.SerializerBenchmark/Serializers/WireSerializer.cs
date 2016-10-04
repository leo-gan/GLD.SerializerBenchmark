/// <summary>
/// See here http://github.com/akkadotnet/wire
/// PM> Install-Package Wire
/// </summary> 

using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class WireSerializer
        : SerDeser
    {
        #region ISerDeser Members

        public override string Name => "WireSerializer";
         private readonly Wire.Serializer _serializer = new  Wire.Serializer(new Wire.SerializerOptions(false, true));

        public override string Serialize(object serializable)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(serializable, ms);
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
                return _serializer.Deserialize(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            _serializer.Serialize(serializable, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize(inputStream);
        }

        #endregion
    }
}