using System;
using System.Collections.Generic;
using System.IO;

namespace GLD.SerializerBenchmark
{
    public abstract class SerDeser : ISerDeser
    {
        protected Type _primaryType;
        protected List<Type> _secondaryTypes;
        public bool JustInitialized;

        public abstract string Name { get; }

        /// <summary>Installed package version for CSV (resolved from the library assembly).</summary>
        public virtual string Version => SerializerVersionRegistry.Resolve(Name);

        /// <summary>
        /// Stream-path honesty for CSV StreamMode (B-6). Default native (real Stream API).
        /// Override or use <see cref="StreamModeHelper"/> for adapted / text_on_stream codecs.
        /// </summary>
        public virtual string StreamMode => StreamModeHelper.Resolve(Name);

        public static bool IsArrayType(string testDataName) =>
            testDataName is "grid" or "grid_window";

        public virtual bool Supports(string testDataName) => !IsArrayType(testDataName);

        /// <summary>Run-config type id for this fixture. table and table_project share a CLR type.</summary>
        public string FixtureName { get; private set; } = "";

        public virtual void BindFixture(string testDataName)
        {
            FixtureName = testDataName ?? "";
        }

        protected bool IsTableProject =>
            string.Equals(FixtureName, "table_project", StringComparison.Ordinal);

        public virtual void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            _primaryType = serializablePrimaryType;
            _secondaryTypes = serializableSecondaryTypes;
            JustInitialized = true;
        }

        /// <summary>
        /// Untimed: convert suite fixtures to library-native forms / cache formatters.
        /// Called once per fixture after <see cref="Initialize"/>.
        /// </summary>
        public virtual void PrepareData(object data)
        {
        }

        public virtual object ToDomain(object decoded) => decoded;

        public abstract byte[] SerializeBytes(object serializable);
        public abstract object DeserializeBytes(byte[] serialized);

        protected static byte[] Utf8Bytes(string text) =>
            System.Text.Encoding.UTF8.GetBytes(text ?? "");

        protected static string Utf8Text(byte[] data) =>
            System.Text.Encoding.UTF8.GetString(data ?? System.Array.Empty<byte>());

        public abstract void Serialize(object serializable, Stream outputStream);
        public abstract object Deserialize(Stream inputStream);

        /// Write a finished buffer. Used by codecs whose stream path is the byte path.
        protected static void WriteAll(Stream output, byte[] bytes)
        {
            output.Write(bytes, 0, bytes.Length);
        }

        /// Read a stream into a buffer. rewind=false seeks only when the stream can.
        protected static byte[] ReadAll(Stream input, bool rewind)
        {
            if (rewind || input.CanSeek)
                input.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            input.CopyTo(ms);
            return ms.ToArray();
        }
    }
}
