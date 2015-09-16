using System;
using System.IO;
using System.Runtime.Serialization.Formatters.Binary;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class BinarySerializer : SerDeser
    {
        private readonly BinaryFormatter _formatter = new BinaryFormatter();

        #region ISerDeser Members

        public override string Name
        {
            get { return "MS Binary"; }
        }


        public override string Serialize(object serializable)
        {
            using (var ms = new MemoryStream())
            {
                _formatter.Serialize(ms, serializable);
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
                return _formatter.Deserialize(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            _formatter.Serialize(outputStream, serializable);
        }


        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _formatter.Deserialize(inputStream);
        }

        #endregion
    }
}