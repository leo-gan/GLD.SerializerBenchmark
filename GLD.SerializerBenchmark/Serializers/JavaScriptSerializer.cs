///
/// See here https://msdn.microsoft.com/en-us/library/system.web.script.serialization.javascriptserializer%28v=vs.110%29.aspx
/// using System.Web.Script.Serialization; // reference to System.Web.Extensions (in System.Web.Extensions.dll)
/// 

using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JavaScriptSerializer : SerDeser
    {
        private static readonly System.Web.Script.Serialization.JavaScriptSerializer _serializer =
            new System.Web.Script.Serialization.JavaScriptSerializer();

        #region ISerDeser Members

        public override string Name
        {
            get { return "MS JavaScript"; }
        }

        public override string Serialize(object serializable)
        {
            return _serializer.Serialize(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return _serializer.Deserialize(serialized, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var str = _serializer.Serialize(serializable);
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
            return _serializer.Deserialize(serialized, _primaryType);
        }

        #endregion
    }
}