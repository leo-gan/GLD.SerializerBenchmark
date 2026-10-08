using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq.Expressions;
using System.Reflection;
using Amazon.IonDotnet;
using Amazon.IonDotnet.Builders;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Amazon Ion binary via Amazon.IonDotnet (reader/writer; no POCO mapper).
    /// A reflection plan is compiled in Initialize. String mode is Base64 of the
    /// binary datagram, matching MessagePack-CSharp. Stream mode writes and reads
    /// the harness Stream. Floats are forced to binary64.
    /// https://github.com/amazon-ion/ion-dotnet
    /// </summary>
    internal class AmazonIonDotnetSerializerSer : SerDeser
    {
        private static readonly ConcurrentDictionary<Type, IonPlan> Plans = new();

        private IonPlan _plan;

        public override string Name => "Amazon.IonDotnet";

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _plan = PlanFor(serializablePrimaryType);
            if (serializableSecondaryTypes == null) return;
            foreach (var t in serializableSecondaryTypes)
            {
                if (t != null) PlanFor(t);
            }
        }

        public override string Serialize(object serializable)
        {
            using var ms = new MemoryStream();
            WriteRoot(serializable, ms);
            return Convert.ToBase64String(ms.ToArray());
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            using var ms = new MemoryStream(bytes, writable: false);
            return ReadRoot(ms);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            WriteRoot(serializable, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return ReadRoot(inputStream);
        }

        private void WriteRoot(object value, Stream outputStream)
        {
            // forceFloat64: the default may narrow a double to float32.
            using var writer = IonBinaryWriterBuilder.Build(outputStream, forceFloat64: true);
            WriteAny(writer, _plan, value);
            writer.Finish();
        }

        private object ReadRoot(Stream inputStream)
        {
            using var reader = IonReaderBuilder.Build(inputStream);
            if (reader.MoveNext() == IonType.None)
                throw new InvalidDataException("empty Ion payload");
            return ReadAny(reader, _plan);
        }

        private static void WriteAny(IIonWriter writer, IonPlan plan, object value)
        {
            if (value == null)
            {
                switch (plan.Kind)
                {
                    case IonKind.String:
                        writer.WriteString("");
                        return;
                    case IonKind.List:
                        writer.StepIn(IonType.List);
                        writer.StepOut();
                        return;
                    case IonKind.Struct:
                        writer.StepIn(IonType.Struct);
                        writer.StepOut();
                        return;
                    default:
                        writer.WriteNull();
                        return;
                }
            }

            switch (plan.Kind)
            {
                case IonKind.Bool:
                    writer.WriteBool((bool)value);
                    return;
                case IonKind.Int32:
                    writer.WriteInt((int)value);
                    return;
                case IonKind.Int64:
                    writer.WriteInt((long)value);
                    return;
                case IonKind.Float64:
                    writer.WriteFloat((double)value);
                    return;
                case IonKind.String:
                    writer.WriteString((string)value);
                    return;
                case IonKind.Struct:
                    writer.StepIn(IonType.Struct);
                    var props = plan.Props;
                    for (var i = 0; i < props.Length; i++)
                    {
                        var p = props[i];
                        writer.SetFieldName(p.Name);
                        WriteAny(writer, p.Plan, p.Get(value));
                    }
                    writer.StepOut();
                    return;
                case IonKind.List:
                    writer.StepIn(IonType.List);
                    foreach (var item in (IEnumerable)value)
                        WriteAny(writer, plan.Elem, item);
                    writer.StepOut();
                    return;
                default:
                    throw new NotSupportedException("Ion plan kind " + plan.Kind);
            }
        }

        private static object ReadAny(IIonReader reader, IonPlan plan)
        {
            if (reader.CurrentIsNull)
            {
                switch (plan.Kind)
                {
                    case IonKind.String: return "";
                    case IonKind.List: return Activator.CreateInstance(plan.Type);
                    case IonKind.Struct: return Activator.CreateInstance(plan.Type);
                    default: return null;
                }
            }

            switch (plan.Kind)
            {
                case IonKind.Bool: return reader.BoolValue();
                case IonKind.Int32: return reader.IntValue();
                case IonKind.Int64: return reader.LongValue();
                case IonKind.Float64: return reader.DoubleValue();
                case IonKind.String: return reader.StringValue() ?? "";
                case IonKind.Struct:
                    var obj = Activator.CreateInstance(plan.Type);
                    reader.StepIn();
                    while (reader.MoveNext() != IonType.None)
                    {
                        var name = reader.CurrentFieldName;
                        if (name != null && plan.ByName.TryGetValue(name, out var prop))
                            prop.Set(obj, ReadAny(reader, prop.Plan));
                        else if (reader.CurrentType.IsContainer() && !reader.CurrentIsNull)
                        {
                            reader.StepIn();
                            while (reader.MoveNext() != IonType.None) { }
                            reader.StepOut();
                        }
                    }
                    reader.StepOut();
                    return obj;
                case IonKind.List:
                    var list = (IList)Activator.CreateInstance(plan.Type);
                    reader.StepIn();
                    while (reader.MoveNext() != IonType.None)
                        list.Add(ReadAny(reader, plan.Elem));
                    reader.StepOut();
                    return list;
                default:
                    throw new NotSupportedException("Ion plan kind " + plan.Kind);
            }
        }

        private static IonPlan PlanFor(Type type)
        {
            if (Plans.TryGetValue(type, out var cached)) return cached;
            // Insert a stub first so nested types that point back do not recurse forever.
            var plan = new IonPlan { Type = type };
            if (!Plans.TryAdd(type, plan)) return Plans[type];
            Fill(plan, type);
            return plan;
        }

        private static void Fill(IonPlan plan, Type type)
        {
            if (type == typeof(bool)) { plan.Kind = IonKind.Bool; return; }
            if (type == typeof(int)) { plan.Kind = IonKind.Int32; return; }
            if (type == typeof(long)) { plan.Kind = IonKind.Int64; return; }
            if (type == typeof(double)) { plan.Kind = IonKind.Float64; return; }
            if (type == typeof(string)) { plan.Kind = IonKind.String; return; }
            if (type.IsGenericType && type.GetGenericTypeDefinition() == typeof(List<>))
            {
                plan.Kind = IonKind.List;
                plan.Elem = PlanFor(type.GetGenericArguments()[0]);
                return;
            }
            if (type.IsClass)
            {
                plan.Kind = IonKind.Struct;
                var props = type.GetProperties(BindingFlags.Instance | BindingFlags.Public);
                var slots = new List<PropSlot>(props.Length);
                foreach (var p in props)
                {
                    if (!p.CanRead || !p.CanWrite || p.GetIndexParameters().Length > 0) continue;
                    slots.Add(new PropSlot
                    {
                        Name = p.Name,
                        Plan = PlanFor(p.PropertyType),
                        Get = CompileGetter(p),
                        Set = CompileSetter(p),
                    });
                }
                plan.Props = slots.ToArray();
                plan.ByName = new Dictionary<string, PropSlot>(plan.Props.Length, StringComparer.Ordinal);
                foreach (var s in plan.Props) plan.ByName[s.Name] = s;
                return;
            }
            throw new NotSupportedException("Amazon.IonDotnet has no plan for " + type.FullName);
        }

        private static Func<object, object> CompileGetter(PropertyInfo property)
        {
            var obj = Expression.Parameter(typeof(object), "obj");
            var body = Expression.Convert(
                Expression.Property(Expression.Convert(obj, property.DeclaringType), property),
                typeof(object));
            return Expression.Lambda<Func<object, object>>(body, obj).Compile();
        }

        private static Action<object, object> CompileSetter(PropertyInfo property)
        {
            var obj = Expression.Parameter(typeof(object), "obj");
            var val = Expression.Parameter(typeof(object), "val");
            var assign = Expression.Assign(
                Expression.Property(Expression.Convert(obj, property.DeclaringType), property),
                Expression.Convert(val, property.PropertyType));
            return Expression.Lambda<Action<object, object>>(assign, obj, val).Compile();
        }

        private enum IonKind { Bool, Int32, Int64, Float64, String, Struct, List }

        private sealed class IonPlan
        {
            public Type Type;
            public IonKind Kind;
            public IonPlan Elem;
            public PropSlot[] Props = Array.Empty<PropSlot>();
            public Dictionary<string, PropSlot> ByName;
        }

        private sealed class PropSlot
        {
            public string Name;
            public IonPlan Plan;
            public Func<object, object> Get;
            public Action<object, object> Set;
        }
    }
}
