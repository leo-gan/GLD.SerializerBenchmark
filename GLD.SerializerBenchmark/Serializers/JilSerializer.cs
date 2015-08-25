///
/// https://github.com/kevin-montrose/Jil
/// PM> Install-Package Jil
/// TODO: DateTime fields is still under work.

using System.IO;
using Jil;

namespace GLD.SerializerBenchmark
{
    internal class JilSerializer : ISerDeser
    {
        #region ISerDeser Members

        public string Name {get { return "Jil"; } }

        public string Serialize<T>(object person)
        {
            using (var sw = new StringWriter())
            {
                JSON.Serialize<T>((T)person, sw,
                    new Options(
                        unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
                return sw.ToString();
            }
        }

        public T Deserialize<T>(string serialized)
        {
            using (var sr = new StringReader(serialized))
            {
                return JSON.Deserialize<T>(sr,
                    new Options(
                        unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
            }
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
                JSON.Serialize<T>((T)person, new StreamWriter(outputStream),
                    new Options(
                        unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
        }


        public T Deserialize<T>(Stream inputStream)
        {
                return JSON.Deserialize<T>(new StreamReader(inputStream),
                    new Options(
                        unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
        }

        #endregion
    }
}