///
/// See here https://github.com/rpgmaker/NetJSON
/// >PM Install-Package NetJSON
/// 

using System;
using NetJSON;

namespace GLD.SerializerBenchmark
{
    internal class NetJSONSer : ISerDeser
    {
        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            return NetJSON.NetJSON.Serialize<T>((T)person);
        }

        public T Deserialize<T>(string serialized)
        {
            return NetJSON.NetJSON.Deserialize<T>(serialized);
        }

        #endregion
    }
}