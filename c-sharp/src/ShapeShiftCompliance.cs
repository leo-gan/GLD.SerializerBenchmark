using System;
using System.Collections.Generic;
using System.IO;
using System.Numerics;
using System.Text;
using System.Text.Json;
using ShapeShift;
using ShapeShift.MsgPack;

namespace GLD.SerializerBenchmark
{
    /// <summary>
    /// Compliance decode through ShapeShift's own decoders, not a second parser.
    /// The typed serializer API only accepts a generated contract, so arbitrary
    /// catalog documents are read with the format decoder into a plain tree.
    /// </summary>
    internal static class ShapeShiftCompliance
    {
        public static object DecodeJson(byte[] data, string _)
        {
            var decoder = new ShapeShift.Json.JsonDecoder(data, default, false);
            var value = FromElement(decoder.ReadJsonElement());
            decoder.EnsureEndOfDocument();
            return value;
        }

        public static object DecodeCbor(byte[] data, string _)
        {
            var decoder = new ShapeShift.Cbor.CborDecoder(data);
            var value = ReadCbor(ref decoder);
            decoder.EnsureEndOfDocument();
            return value;
        }

        public static object DecodeMsgPack(byte[] data, string _)
        {
            var decoder = new ShapeShift.MsgPack.MsgPackDecoder(data);
            var value = ReadMsgPack(ref decoder);
            decoder.EnsureEndOfDocument();
            return value;
        }

        public static object DecodeToml(byte[] data, string _)
        {
            using var reader = new StringReader(Encoding.UTF8.GetString(data));
            var decoder = new ShapeShift.Toml.TomlDecoder(reader);
            var value = ReadToml(ref decoder);
            if (decoder.NextTokenType != TokenType.EndDocument)
                throw new InvalidDataException("trailing data after the document");
            return value;
        }

        public static object DecodeYaml(byte[] data, string _)
        {
            using var reader = new StringReader(Encoding.UTF8.GetString(data));
            var decoder = new ShapeShift.Yaml.YamlDecoder(reader);
            // An empty or comment-only stream is a valid YAML document with no
            // value. The decoder reports EndDocument instead of throwing.
            if (decoder.NextTokenType == TokenType.EndDocument)
                return null;
            var value = ReadYaml(ref decoder);
            // YamlSerializer has no multi-document reader (unlike JSON and
            // MessagePack). Leftover tokens are a document this decoder did not
            // consume, not a second document it parsed. Do not stitch those
            // tokens into a list: `---` is ordinary text here.
            if (decoder.NextTokenType != TokenType.EndDocument)
                throw new InvalidDataException("trailing data after the document");
            return value;
        }

        private static object FromElement(JsonElement el)
        {
            switch (el.ValueKind)
            {
                case JsonValueKind.Object:
                    var map = new Dictionary<string, object>();
                    foreach (var prop in el.EnumerateObject())
                        map[prop.Name] = FromElement(prop.Value);
                    return map;
                case JsonValueKind.Array:
                    var list = new List<object>();
                    foreach (var item in el.EnumerateArray())
                        list.Add(FromElement(item));
                    return list;
                case JsonValueKind.String:
                    return el.GetString();
                case JsonValueKind.Number:
                    if (el.TryGetInt64(out var n)) return n;
                    return el.GetDouble();
                case JsonValueKind.True:
                    return true;
                case JsonValueKind.False:
                    return false;
                case JsonValueKind.Null:
                    return null;
                default:
                    throw new InvalidDataException("unsupported JSON token " + el.ValueKind);
            }
        }

        private static string KeyText(ReadOnlySpan<char> name) => name.ToString();

        private static object ReadCbor(ref ShapeShift.Cbor.CborDecoder d)
        {
            switch (d.NextTokenType)
            {
                case TokenType.Null:
                    d.ReadNull();
                    return null;
                case TokenType.Boolean:
                    return d.ReadBoolean();
                case TokenType.String:
                    return d.ReadString();
                case TokenType.Number:
                    return Primitive(d.ReadDynamicNumber());
                case TokenType.Binary:
                    return d.ReadByteArray();
                case TokenType.StartVector:
                    d.ReadStartVector();
                    var list = new List<object>();
                    while (d.NextTokenType != TokenType.EndVector)
                        list.Add(ReadCbor(ref d));
                    d.ReadEndVector();
                    return list;
                case TokenType.StartMap:
                    d.ReadStartMap();
                    var map = new Dictionary<string, object>();
                    while (d.NextTokenType != TokenType.EndMap)
                    {
                        string key;
                        if (d.NextTokenType == TokenType.PropertyName)
                            key = KeyText(d.ReadPropertyName());
                        else
                            key = Convert.ToString(ReadCbor(ref d)) ?? "";
                        map[key] = ReadCbor(ref d);
                    }
                    d.ReadEndMap();
                    return map;
                default:
                    throw new InvalidDataException("unsupported token " + d.NextTokenType);
            }
        }

        private static object ReadMsgPack(ref ShapeShift.MsgPack.MsgPackDecoder d)
        {
            switch (d.NextTokenType)
            {
                case TokenType.Null:
                    d.ReadNull();
                    return null;
                case TokenType.Boolean:
                    return d.ReadBoolean();
                case TokenType.String:
                    return d.ReadString();
                case TokenType.Number:
                    return Primitive(d.ReadDynamicNumber());
                case TokenType.Binary:
                    return ReadMsgPackBinary(ref d);
                case TokenType.StartVector:
                    d.ReadStartVector();
                    var list = new List<object>();
                    while (d.NextTokenType != TokenType.EndVector)
                        list.Add(ReadMsgPack(ref d));
                    d.ReadEndVector();
                    return list;
                case TokenType.StartMap:
                    d.ReadStartMap();
                    var map = new Dictionary<string, object>();
                    while (d.NextTokenType != TokenType.EndMap)
                    {
                        string key;
                        if (d.NextTokenType == TokenType.PropertyName)
                            key = KeyText(d.ReadPropertyName());
                        else
                            key = Convert.ToString(ReadMsgPack(ref d)) ?? "";
                        map[key] = ReadMsgPack(ref d);
                    }
                    d.ReadEndMap();
                    return map;
                default:
                    throw new InvalidDataException("unsupported token " + d.NextTokenType);
            }
        }

        private static object ReadToml(ref ShapeShift.Toml.TomlDecoder d)
        {
            switch (d.NextTokenType)
            {
                case TokenType.Null:
                    d.ReadNull();
                    return null;
                case TokenType.Boolean:
                    return d.ReadBoolean();
                case TokenType.String:
                    return d.ReadString();
                case TokenType.Number:
                    return Primitive(d.ReadDynamicNumber());
                case TokenType.Binary:
                    return d.ReadByteArray();
                case TokenType.StartVector:
                    d.ReadStartVector();
                    var list = new List<object>();
                    while (d.NextTokenType != TokenType.EndVector)
                        list.Add(ReadToml(ref d));
                    d.ReadEndVector();
                    return list;
                case TokenType.StartMap:
                    d.ReadStartMap();
                    var map = new Dictionary<string, object>();
                    while (d.NextTokenType != TokenType.EndMap)
                    {
                        string key;
                        if (d.NextTokenType == TokenType.PropertyName)
                            key = KeyText(d.ReadPropertyName());
                        else
                            key = Convert.ToString(ReadToml(ref d)) ?? "";
                        map[key] = ReadToml(ref d);
                    }
                    d.ReadEndMap();
                    return map;
                default:
                    throw new InvalidDataException("unsupported token " + d.NextTokenType);
            }
        }

        private static object ReadYaml(ref ShapeShift.Yaml.YamlDecoder d)
        {
            switch (d.NextTokenType)
            {
                case TokenType.Null:
                    d.ReadNull();
                    return null;
                case TokenType.Boolean:
                    return d.ReadBoolean();
                case TokenType.String:
                    return d.ReadString();
                case TokenType.Number:
                    return Primitive(d.ReadDynamicNumber());
                case TokenType.Binary:
                    return d.ReadByteArray();
                case TokenType.StartVector:
                    d.ReadStartVector();
                    var list = new List<object>();
                    while (d.NextTokenType != TokenType.EndVector)
                        list.Add(ReadYaml(ref d));
                    d.ReadEndVector();
                    return list;
                case TokenType.StartMap:
                    d.ReadStartMap();
                    var map = new Dictionary<string, object>();
                    while (d.NextTokenType != TokenType.EndMap)
                    {
                        string key;
                        if (d.NextTokenType == TokenType.PropertyName)
                            key = KeyText(d.ReadPropertyName());
                        else
                            key = Convert.ToString(ReadYaml(ref d)) ?? "";
                        map[key] = ReadYaml(ref d);
                    }
                    d.ReadEndMap();
                    return map;
                default:
                    throw new InvalidDataException("unsupported token " + d.NextTokenType);
            }
        }

        /// <summary>
        /// MessagePack surfaces every non-numeric extension as <see cref="TokenType.Binary"/>.
        /// <see cref="MsgPackDecoder.ReadByteArray"/> only reads the bin family, so timestamp
        /// (type −1) and other extensions have to go through the extension API.
        /// </summary>
        private static object ReadMsgPackBinary(ref MsgPackDecoder d)
        {
            if (!d.TryPeekExtensionHeader(out MsgPackExtensionHeader header))
                return d.ReadByteArray();
            if (header.TypeCode == MsgPackExtensionCodes.Timestamp)
                return d.ReadDateTime();
            return d.ReadExtension(header.TypeCode);
        }

        /// <summary>
        /// <see cref="ShapeShiftNumber"/> is ShapeShift's dynamic number. Compliance compares
        /// ordinary CLR numbers, the same way a caller uses <c>Value</c> after
        /// <c>ReadDynamicNumber</c>. Whole decimals become integers so <c>3</c> stays <c>3</c>.
        /// </summary>
        private static object Primitive(ShapeShiftNumber number)
        {
            switch (number)
            {
                case ShapeShiftInteger integer:
                    return integer.Value;
                case ShapeShiftUnsignedInteger unsigned:
                    return unsigned.Value <= (ulong)long.MaxValue ? (long)unsigned.Value : unsigned.Value;
                case ShapeShiftFloat floating:
                    return floating.Value;
                case ShapeShiftDecimal dec:
                    return WholeDecimal(dec.Value);
                case ShapeShiftBigInteger big:
                    return big.Value >= long.MinValue && big.Value <= long.MaxValue
                        ? (long)big.Value
                        : big.Value;
                default:
                    return number;
            }
        }

        private static object WholeDecimal(decimal value)
        {
            if (value == decimal.Truncate(value) && value >= long.MinValue && value <= long.MaxValue)
                return (long)value;
            return (double)value;
        }
    }
}
