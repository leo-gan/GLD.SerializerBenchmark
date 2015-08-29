///
/// https://github.com/tomba/netserializer
/// PM> Install-Package NetSerializer
///

using System;
using System.Collections.Generic;
using System.IO;
using NetSerializer;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class NetSerializerSer : SerDeser
    {
        private Serializer _serializer;

         private void Initialize()
        {
            if (!JustInitialized) return;
            var typeList = new List<Type> {_primaryType};
            typeList.AddRange(_secondaryTypes);
            _serializer = new Serializer(typeList);
            JustInitialized = false;
        }

        #region ISerDeser Members

        public override string Name
        {
            get { return "NetSerializer"; }
        }

        public override string Serialize(object serializable)
        {
            Initialize();
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(ms, serializable);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public override object Deserialize(string serialized)
        {
            Initialize();
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return _serializer.Deserialize(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Initialize();
            _serializer.Serialize(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            Initialize();
             inputStream.Seek(0, SeekOrigin.Begin);
           return _serializer.Deserialize(inputStream);
        }

        #endregion
    }
}