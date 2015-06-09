/// https://github.com/aumcode/nfx
/// Clone a project from GitHub b compile it. Add reference to NFX.dll 

using System;
using System.Collections.Generic;
using System.IO;
using NFX.Serialization.Slim;

namespace GLD.SerializerBenchmark
{
    internal class SlimSerializer : ISerDeser
    {
        private readonly NFX.Serialization.Slim.SlimSerializer _serializer;

        #region ISerDeser Members

        public SlimSerializer(IEnumerable<Type> types)
        {
            var treg = new TypeRegistry(types, TypeRegistry.BoxedCommonNullableTypes, TypeRegistry.BoxedCommonTypes );
            _serializer = new NFX.Serialization.Slim.SlimSerializer(treg);
        }

        public string Serialize<T>(object person)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(ms, (T) person);
                ms.Flush();
                // ms.Position = 0;
                return Convert.ToBase64String(ms.GetBuffer(), 0, (int)ms.Position, Base64FormattingOptions.None);
            }
        }

        public T Deserialize<T>(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return (T) _serializer.Deserialize(stream);
            }
        }

        #endregion
    }
}