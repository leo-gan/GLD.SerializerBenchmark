/// https://github.com/aumcode/nfx
/// Clone a project from GitHub b compile it. Add reference to NFX.dll 
using System;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal class SlimSerializer : ISerDeser
    {
        private readonly NFX.Serialization.Slim.SlimSerializer _serializer = new NFX.Serialization.Slim.SlimSerializer();

        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(ms, (T) person);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
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