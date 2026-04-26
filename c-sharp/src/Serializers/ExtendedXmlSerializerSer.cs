using System;
using System.IO;
using ExtendedXmlSerializer;
using ExtendedXmlSerializer.Configuration;
using System.Reflection;
using System.Linq;

namespace GLD.SerializerBenchmark.Serializers
{
    // ExtendedXmlSerializer
    internal class ExtendedXmlSerializerSer : SerDeser
    {
        private readonly IExtendedXmlSerializer _serializer;
        private static MethodInfo _deserializeMethod;

        public ExtendedXmlSerializerSer()
        {
            _serializer = new ConfigurationContainer().Create();
            if (_deserializeMethod == null)
            {
                _deserializeMethod = typeof(IExtendedXmlSerializer).GetMethods()
                    .FirstOrDefault(m => m.Name == "Deserialize" && m.IsGenericMethod && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(string));
            }
        }

        public override string Name => "ExtendedXmlSerializer";

        public override bool Supports(string testDataName)
        {
            // ExtendedXmlSerializer requires special configuration for circular references
            // and has comparison errors on most types
            return testDataName == "Integer";
        }

        public override string Serialize(object serializable)
        {
            return _serializer.Serialize(serializable);
        }

        public override object Deserialize(string serialized)
        {
            if (_deserializeMethod == null) return null;
            var generic = _deserializeMethod.MakeGenericMethod(_primaryType);
            return generic.Invoke(_serializer, new object[] { serialized });
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            using (var sw = new StreamWriter(outputStream, System.Text.Encoding.UTF8, 1024, true))
            {
                sw.Write(_serializer.Serialize(serializable));
            }
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using (var sr = new StreamReader(inputStream, System.Text.Encoding.UTF8, false, 1024, true))
            {
                var serialized = sr.ReadToEnd();
                return Deserialize(serialized);
            }
        }
    }
}
