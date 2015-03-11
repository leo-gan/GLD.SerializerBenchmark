///
/// See here https://msdn.microsoft.com/en-us/library/system.web.script.serialization.javascriptserializer%28v=vs.110%29.aspx
/// using System.Web.Script.Serialization; // reference to System.Web.Extensions (in System.Web.Extensions.dll)
/// 

using System;
using System.IO;
using System.Web.Script.Serialization;

namespace GLD.SerializerBenchmark
{
    internal class JavaScriptSerializer : ISerDeser
    {
        private static  System.Web.Script.Serialization.JavaScriptSerializer _serializer =
            new System.Web.Script.Serialization.JavaScriptSerializer();

 #region ISerDeser Members

        public string Serialize<T>(object person)
        {
                return _serializer.Serialize(person);
        }

        public T Deserialize<T>(string serialized)
        {
            return (T) _serializer.Deserialize<T>(serialized);
          }

        #endregion
    }
}