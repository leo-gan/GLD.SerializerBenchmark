///
/// See here https://msdn.microsoft.com/en-us/library/system.web.script.serialization.javascriptserializer%28v=vs.110%29.aspx
/// using System.Web.Script.Serialization; // reference to System.Web.Extensions (in System.Web.Extensions.dll)
/// 

using System.IO;
using System.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JavaScriptSerializer : SerDeser
    {
        private static readonly System.Web.Script.Serialization.JavaScriptSerializer _serializer =
            new System.Web.Script.Serialization.JavaScriptSerializer();

        #region ISerDeser Members

        public override string Name {get { return "MS JavaScript"; } }
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
            //var sr = new StringReader(_serializer.Serialize(serializable));
            //sr.ReadToEnd();
             throw new System.NotImplementedException();
       }

        public override object Deserialize(Stream inputStream)
        {
            //var sb = new StringBuilder();
            //var sw = new StringWriter(sb);
            //string s = sw.ToString(); // ???
            //return _serializer.Deserialize(s, _primaryType);
             throw new System.NotImplementedException();
       }
        #endregion
    }
}