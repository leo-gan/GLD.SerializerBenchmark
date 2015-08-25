///
/// See here https://msdn.microsoft.com/en-us/library/system.web.script.serialization.javascriptserializer%28v=vs.110%29.aspx
/// using System.Web.Script.Serialization; // reference to System.Web.Extensions (in System.Web.Extensions.dll)
/// 

using System.IO;
using System.Text;

namespace GLD.SerializerBenchmark
{
    internal class JavaScriptSerializer : ISerDeser
    {
        private static readonly System.Web.Script.Serialization.JavaScriptSerializer _serializer =
            new System.Web.Script.Serialization.JavaScriptSerializer();

        #region ISerDeser Members

        public string Name {get { return "MS JavaScript"; } }

        public string Serialize<T>(object person)
        {
            return _serializer.Serialize(person);
        }

        public T Deserialize<T>(string serialized)
        {
            return _serializer.Deserialize<T>(serialized);
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
            var sr = new StringReader(_serializer.Serialize( person));
            sr.ReadToEnd();
            //outputStream.
        }


        public T Deserialize<T>(Stream inputStream)
        {
            var sb = new StringBuilder();
            var sw = new StringWriter(sb);
            string s = sw.ToString(); // ???
            return _serializer.Deserialize<T>(s);
        }

        #endregion
    }
}