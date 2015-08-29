///
/// See here https://github.com/msgpack/msgpack-cli
/// >PM Install-Package MsgPack.Cli
/// 

using System;
using System.IO;
using GLD.SerializerBenchmark.TestData;
using MsgPack.Serialization;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    ///     NOTE: Tests result got the errors:
    ///     ************** Comparison failed!
    ///     Passport.ExpirationDate: 10/23/2017 00:46:03 != 10/23/2017 00:46:03
    ///     The reason described here [https://github.com/msgpack/msgpack-cli/wiki]
    ///     "This is a limitation of the MessagePack spec. There are no canonical specification to serialize date/time value,
    ///     but the de facto is usage of the Unix epoc which is an epoc from January 1st, 1970 by milliseconds. MessagePack for
    ///     CLI is compliant for this, so less significant digits and timezone related information of DateTime/DateTimeOffset
    ///     will be lost. Error that built-in serealiers pack them in UTC time."
    ///     I am leaving it now at it is.
    /// </summary>
    internal class MsgPackSerializer : SerDeser
    {
        private static  IMessagePackSerializer _serializer;

        // TODO: Hack! How to get a type of the person object? In XmlSerializer it works, not here!

        private void Initialize()
        {
            if (!base.JustInitialized) return;
            _serializer = MessagePackSerializer.Get(_primaryType);
            JustInitialized = false;
        }

        #region ISerDeser Members

        public override string Name {get { return "MsgPack"; } }
        public override string Serialize(object serializable)
        {
            Initialize();
            using (var ms = new MemoryStream())
            {
                _serializer.Pack(ms, serializable);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public override object Deserialize(string serialized)
        {
            Initialize();
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return _serializer.Unpack(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Initialize();
            _serializer.Pack(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            Initialize();
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Unpack(inputStream);
        }
        #endregion
    }
}