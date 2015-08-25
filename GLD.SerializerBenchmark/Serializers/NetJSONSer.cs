///
/// See here https://github.com/rpgmaker/NetJSON
/// >PM Install-Package NetJSON
/// 

using System;
using System.IO;
using NetJSON;

namespace GLD.SerializerBenchmark
{
    internal class NetJSONSer : ISerDeser
    {
        #region ISerDeser Members

        public string Name {get { return "NetJSON"; } }

        public string Serialize<T>(object person)
        {
            return NetJSON.NetJSON.Serialize<T>((T)person);
        }

        public T Deserialize<T>(string serialized)
        {
            return NetJSON.NetJSON.Deserialize<T>(serialized);
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
            NetJSON.NetJSON.Serialize<T>((T)person, new StreamWriter(outputStream));
        }


        public T Deserialize<T>(Stream inputStream)
        {
            return NetJSON.NetJSON.Deserialize<T>(new StreamReader(inputStream));
        }

        #endregion
    }
}