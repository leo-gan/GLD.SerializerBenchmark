using System.IO;
using System.Text.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class JavaScriptSerializerSer : SerDeser
    {
        #region ISerDeser Members

        public override string Name
        {
            get { return "MS System.Text.Json"; }
        }

        public override string Serialize(object serializable)
        {
            return JsonSerializer.Serialize(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return JsonSerializer.Deserialize(serialized, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            JsonSerializer.Serialize(outputStream, serializable);
            outputStream.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return JsonSerializer.Deserialize(inputStream, _primaryType);
        }

        #endregion
    }
}
