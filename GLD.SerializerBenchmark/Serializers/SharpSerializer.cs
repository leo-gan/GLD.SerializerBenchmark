///
/// See here http://www.sharpserializer.com/en/index.html
/// >PM Install-Package SharpSerializer
/// 

using System;
using System.IO;
using Polenter.Serialization;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class SharpSerializer : SerDeser
    {
        // Create a new serializer instance per operation to avoid threading issues
        // Using XML settings for better compatibility with arrays
        private static Polenter.Serialization.SharpSerializer CreateSerializer()
        {
            var settings = new SharpSerializerXmlSettings();
            return new Polenter.Serialization.SharpSerializer(settings);
        }

        #region ISerDeser Members

        public override string Name
        {
            get { return "SharpSerializer"; }
        }

        public override bool Supports(string testDataName)
        {
            // SharpSerializer has issues with Person and Telemetry test data
            // causing NullReferenceException during serialization
            return testDataName != "Person" && testDataName != "Telemetry";
        }

        public override string Serialize(object serializable)
        {
            if (serializable == null)
                throw new ArgumentNullException(nameof(serializable));
                
            var serializer = CreateSerializer();
            using (var ms = new MemoryStream())
            {
                serializer.Serialize(serializable, ms);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public override object Deserialize(string serialized)
        {
            if (string.IsNullOrEmpty(serialized))
                throw new ArgumentNullException(nameof(serialized));
                
            var serializer = CreateSerializer();
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return serializer.Deserialize(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            if (serializable == null)
                throw new ArgumentNullException(nameof(serializable));
            if (outputStream == null)
                throw new ArgumentNullException(nameof(outputStream));
                
            var serializer = CreateSerializer();
            serializer.Serialize(serializable, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            if (inputStream == null)
                throw new ArgumentNullException(nameof(inputStream));
                
            var serializer = CreateSerializer();
            inputStream.Seek(0, SeekOrigin.Begin);
            return serializer.Deserialize(inputStream);
        }

        #endregion
    }
}