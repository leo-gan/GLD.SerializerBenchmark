/// https://github.com/aumcode/nfx
/// >PM Install-Package NFX

using System;
using System.Collections.Generic;
using System.IO;
using NFX.Serialization.JSON;
using ServiceStack;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class NfxJsonSerializer : SerDeser
    {
         #region ISerDeser Members

        public override string Name
        {
            get { return "NFX.Json"; }
        }

        public override string Serialize(object serializable)
        {
            return JSONWriter.Write(serializable, JSONWritingOptions.Compact);
        }

        public override object Deserialize(string serialized)
        {
            return JSONReader.DeserializeDataObject(serialized).ConvertTo<object>();
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            JSONWriter.Write(serializable, outputStream, JSONWritingOptions.Compact);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return JSONReader.DeserializeDataObject(inputStream).ConvertTo<object>();
        }
        #endregion
    }
}