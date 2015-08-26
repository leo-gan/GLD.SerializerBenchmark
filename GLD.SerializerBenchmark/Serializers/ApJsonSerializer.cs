///
/// See http://www.codeproject.com/Articles/491742/APJSON
/// Manually download a dll from mentioned site and add a reference to it.
/// 

using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ApJsonSerializer : SerDeser
    {
 
        #region ISerDeser Members

        public override string Name {get { return "Apolyton.Json"; } }
        public override string Serialize(object serializable)
        {
            return Apolyton.FastJson.Json.Current.ToJson(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return Apolyton.FastJson.Json.Current.ReadObject(serialized, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            throw new NotImplementedException();
        }

        public override object Deserialize(Stream inputStream)
        {
            throw new NotImplementedException();
        }
        #endregion
    }
}