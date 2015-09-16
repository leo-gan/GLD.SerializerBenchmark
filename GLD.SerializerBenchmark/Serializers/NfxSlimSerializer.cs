/// https://github.com/aumcode/nfx
/// >PM Install-Package NFX

using System;
using System.Collections.Generic;
using System.IO;
using NFX.Serialization.Slim;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class NfxSlimSerializer : SerDeser
    {
        private SlimSerializer _serializer;

        #region ISerDeser Members

        private void Initialize()
        {
            if (!JustInitialized) return;
            var typeList = new List<Type> {_primaryType};
            if (_secondaryTypes != null) typeList.AddRange(_secondaryTypes);
            var treg = new TypeRegistry(
                typeList,
                TypeRegistry.BoxedCommonTypes,
                TypeRegistry.BoxedCommonNullableTypes,
                TypeRegistry.CommonCollectionTypes
                );
            _serializer = new SlimSerializer(treg);
            JustInitialized = false;
        }

        public override string Name
        {
            get { return "NFX.Slim"; }
        }

        public override string Serialize(object serializable)
        {
            Initialize();
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(ms, serializable);
                ms.Flush();
                // ms.Position = 0;
                return Convert.ToBase64String(ms.GetBuffer(), 0, (int) ms.Position, Base64FormattingOptions.None);
            }
        }

        public override object Deserialize(string serialized)
        {
            Initialize();
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return _serializer.Deserialize(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Initialize();
            _serializer.Serialize(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            Initialize();
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize(inputStream);
        }

        #endregion
    }
}