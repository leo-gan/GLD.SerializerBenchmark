///
/// https://github.com/jsonfx/jsonfx
/// PM> Install-Package JsonFx
/// by Stephen McKamey
/// 

using System.IO;
using JsonFx.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JsonFxSerializer : SerDeser
    {

        static readonly JsonWriter _jw = new JsonWriter();
        static readonly JsonReader _jr = new JsonReader();
        #region ISerDeser Members

        public override string Name {get { return "JsonFx"; } }
        public override string Serialize(object serializable)
        {
            return _jw.Write(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return _jr.Read(serialized, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            _jw.Write(serializable, new StreamWriter(outputStream));
        }

        public override object Deserialize(Stream inputStream)
        {
            return _jr.Read(new StreamReader(inputStream), _primaryType);
        }
        #endregion
    }
}