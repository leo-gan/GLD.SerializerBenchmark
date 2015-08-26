///
/// See https://github.com/alibaba/fastjson
/// >PM Install-Package fastJSON
/// 

using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    internal class FastJsonSerializer : SerDeser
    {
 
        #region ISerDeser Members

        public override string Name {get { return "fastJson"; } }
        public override string Serialize(object serializable)
        {
               return fastJSON.JSON.ToJSON(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return fastJSON.JSON.ToObject(serialized);
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