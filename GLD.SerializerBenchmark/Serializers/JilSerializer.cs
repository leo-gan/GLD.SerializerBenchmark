///
/// https://github.com/kevin-montrose/Jil
/// PM> Install-Package Jil
/// TODO: DateTime fields is still under work.

using System.IO;
using Jil;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JilSerializer : SerDeser
    {
        #region ISerDeser Members

        public override string Name {get { return "Jil"; } }
        public override string Serialize(object serializable)
        {
            using (var sw = new StringWriter())
            {
                JSON.Serialize(serializable, sw,
                    new Options(
                        unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
                return sw.ToString();
            }
        }

        public override object Deserialize(string serialized)
        {
            using (var sr = new StringReader(serialized))
            {
                return JSON.Deserialize(sr, _primaryType,
                    new Options(
                        unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
                JSON.Serialize(serializable, new StreamWriter(outputStream),
                    new Options(
                        unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
                return JSON.Deserialize(new StreamReader(inputStream), _primaryType,
                    new Options(
                        unspecifiedDateTimeKindBehavior: UnspecifiedDateTimeKindBehavior.IsUTC));
        }
        #endregion
    }
}