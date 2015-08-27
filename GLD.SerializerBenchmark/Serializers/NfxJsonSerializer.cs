/// https://github.com/aumcode/nfx
/// >PM Install-Package NFX

using System;
using System.Collections.Generic;
using System.IO;
using NFX.Serialization.JSON;
using ServiceStack;

namespace GLD.SerializerBenchmark
{
    internal class NfxJsonSerializer : ISerDeser
    {
        #region ISerDeser Members

        public NfxJsonSerializer(IEnumerable<Type> types)
        {
        }

        public string Name
        {
            get { return "NFX.Json"; }
        }

        public string Serialize<T>(object person)
        {
            return JSONWriter.Write(person, JSONWritingOptions.Compact);
        }

        public T Deserialize<T>(string serialized)
        {
            dynamic dyna = JSONReader.DeserializeDataObject(serialized).ConvertTo<T>();
            return (T) dyna;
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
            JSONWriter.Write(person, outputStream, JSONWritingOptions.Compact);
        }


        public T Deserialize<T>(Stream inputStream)
        {
            dynamic dyna = JSONReader.DeserializeDataObject(inputStream).ConvertTo<T>();
            return (T) dyna;
        }

        #endregion
    }
}