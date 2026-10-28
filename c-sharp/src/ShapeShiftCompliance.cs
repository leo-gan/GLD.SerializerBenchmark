using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using ShapeShift;

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
            var value = ReadYaml(ref decoder);
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
                    return d.ReadDynamicNumber();
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
                    return d.ReadDynamicNumber();
                case TokenType.Binary:
                    return d.ReadByteArray();
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
                    return d.ReadDynamicNumber();
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
                    return d.ReadDynamicNumber();
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
    }
}
