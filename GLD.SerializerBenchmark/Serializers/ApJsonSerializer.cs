///
/// See http://www.codeproject.com/Articles/491742/APJSON
/// Manually download a dll from mentioned site and add a reference to it.
/// 

using System.IO;
using Apolyton.FastJson;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ApJsonSerializer : SerDeser
    {
        #region ISerDeser Members

        public override string Name
        {
            get { return "Apolyton.Json"; }
        }

        public override string Serialize(object serializable)
        {
            return Json.Current.ToJson(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return Json.Current.ReadObject(serialized, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var str = Json.Current.ToJson(serializable);
            var sw = new StreamWriter(outputStream);
            outputStream.Seek(0, SeekOrigin.Begin);
            sw.Write(str);
            sw.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            var sr = new StreamReader(inputStream);
            inputStream.Seek(0, SeekOrigin.Begin);
            var serialized = sr.ReadToEnd();
            return Json.Current.ReadObject(serialized, _primaryType);
        }

        #endregion
    }
}