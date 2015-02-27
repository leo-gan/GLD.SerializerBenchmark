///
/// See here https://github.com/Microsoft/bond/
/// >PM Install-Package Microsoft.Hadoop.Avro
/// 
using System;
using Bond;
using Bond.IO.Safe;
using Bond.Protocols;

namespace GLD.SerializerBenchmark
{
    public static class BondTypeAliasConverter
    {
        public static long Convert(DateTime value, long unused)
        {
            return value.Ticks;
        }

        public static DateTime Convert(long value, DateTime unused)
        {
            return new DateTime(value);
        }
    }

    internal class BondSerializer : ISerDeser
    {
        private readonly Deserializer<CompactBinaryReader<InputBuffer>> _deserializer;
        private readonly Serializer<CompactBinaryWriter<OutputBuffer>> _serializer;

        public BondSerializer(Type personType)
        {
            _serializer = new Serializer<CompactBinaryWriter<OutputBuffer>>(personType);
            _deserializer = new Deserializer<CompactBinaryReader<InputBuffer>>(personType);
        }

        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            var output = new OutputBuffer();
            var writer = new CompactBinaryWriter<OutputBuffer>(output);
            _serializer.Serialize((T)person, writer);
            return Convert.ToBase64String(output.Data.Array);
        }

        public T Deserialize<T>(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            var input = new InputBuffer(bytes);
            var reader = new CompactBinaryReader<InputBuffer>(input);
            return (T) _deserializer.Deserialize(reader);
        }

        #endregion
    }
}