///
/// See here http://azure.microsoft.com/en-us/documentation/articles/hdinsight-dotnet-avro-serialization/
/// >PM Install-Package Microsoft.Hadoop.Avro
/// 

using System;
using System.IO;
using Microsoft.Hadoop.Avro;

namespace GLD.SerializerBenchmark
{
    /// <summary>
    ///     NOTE: Tests result got the errors:
    ///     ************** Comparison failed!
    ///     Passport.ExpirationDate: 10/23/2017 00:46:03 != 10/23/2017 00:46:03
    ///     The reason described here [https://github.com/msgpack/msgpack-cli/wiki]
    ///     "This is a limitation of the MessagePack spec. There are no canonical specification to serialize date/time value,
    ///     but the de facto is usage of the Unix epoc which is an epoc from January 1st, 1970 by milliseconds. MessagePack for
    ///     CLI is compliant for this, so less significant digits and timezone related information of DateTime/DateTimeOffset
    ///     will be lost. Note that built-in serealiers pack them in UTC time."
    ///     I am leaving it now at it is.
    /// </summary>
    internal class AvroSerializer : ISerDeser
    {
        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            // TODO: Hack! How to get a type of the person object? In XmlSerializer it works, not here!
            // The serialize is typed and type should be know upfront.
            var serializer =
                Microsoft.Hadoop.Avro.AvroSerializer.Create<Person>();

            using (var ms = new MemoryStream())
            {
                serializer.Serialize(ms, (Person) person);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public T Deserialize<T>(string serialized)
        {
            var serializer = Microsoft.Hadoop.Avro.AvroSerializer.Create<T>();

            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return serializer.Deserialize(stream);
            }
        }

        #endregion
    }
}