///
/// See here https://github.com/msgpack/msgpack-cli
/// >PM Install-Package MsgPack.Cli
/// 

using System;
using System.IO;
using MsgPack.Serialization;

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
    internal class MsgPackSerializer : ISerDeser
    {
        private static readonly IMessagePackSerializer _serializer =
            MessagePackSerializer.Get((typeof (Person)));

        // TODO: Hack! How to get a type of the person object? In XmlSerializer it works, not here!

        //public MsgPackSerializer (Person t)
        //{
        //    var _serializer = MsgPack.Serialization.SerializationContext.Default.GetSerializer<Person>();
        //}

        #region ISerDeser Members

        public string Serialize<T>(object person)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Pack(ms, (T)person);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public T Deserialize<T>(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return (T) _serializer.Unpack(stream);
            }
        }

        #endregion
    }
}