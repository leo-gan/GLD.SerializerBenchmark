///
/// System.Runtime.Serialization.dll 
/// 

using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class DataContractJsonSer : SerDeser
    {
        private  System.Runtime.Serialization.Json.DataContractJsonSerializer _serializer = null;

         private void Initialize()
        {
            if (!base.JustInitialized) return;
             _serializer = new System.Runtime.Serialization.Json.DataContractJsonSerializer(_primaryType, _secondaryTypes);
           JustInitialized = false;
        }
 
        #region ISerDeser Members

        public override string Name {get { return "MS DataContract Json"; } }
        public override string Serialize(object serializable)
        {
            Initialize();
            using (var stream = new MemoryStream())
            {
                _serializer.WriteObject(stream, serializable);
                stream.Flush();
                stream.Position = 0;
                return Convert.ToBase64String(stream.ToArray());
            }
        }

        public override object Deserialize(string serialized)
        {
            Initialize();
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return  _serializer.ReadObject(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Initialize();
            _serializer.WriteObject(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            Initialize();
            return  _serializer.ReadObject(inputStream);
        }
        #endregion
    }
}