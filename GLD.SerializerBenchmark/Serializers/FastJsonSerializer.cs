///
/// See https://github.com/alibaba/fastjson
/// >PM Install-Package fastJSON
/// 

using System.IO;
using fastJSON;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    internal class FastJsonSerializer : SerDeser
    {
        #region ISerDeser Members

        public override string Name
        {
            get { return "fastJson"; }
        }

        public override string Serialize(object serializable)
        {
            return JSON.ToJSON(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return JSON.ToObject(serialized);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var str = JSON.ToJSON(serializable);
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
            return JSON.ToObject(serialized);
        }

        #endregion
    }
}