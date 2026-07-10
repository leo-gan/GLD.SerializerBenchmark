using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Build typed Serialize/Deserialize delegates from a runtime <see cref="Type"/>
    /// without hard-coding suite model names. Bind once in Initialize (untimed).
    /// </summary>
    internal static class TypedSer
    {
        public static Func<object, byte[]> BindSerializeBytes(
            Type valueType,
            MethodInfo openGenericSerialize,
            object target = null)
        {
            if (openGenericSerialize == null) throw new ArgumentNullException(nameof(openGenericSerialize));
            if (!openGenericSerialize.IsGenericMethodDefinition)
                throw new ArgumentException("expected open generic method", nameof(openGenericSerialize));

            var closed = openGenericSerialize.MakeGenericMethod(valueType);
            var p = Expression.Parameter(typeof(object), "o");
            var cast = Expression.Convert(p, valueType);
            Expression call = closed.IsStatic
                ? Expression.Call(closed, cast)
                : Expression.Call(Expression.Constant(target), closed, cast);
            return Expression.Lambda<Func<object, byte[]>>(
                Expression.Convert(call, typeof(byte[])), p).Compile();
        }

        public static Func<byte[], object> BindDeserializeBytes(
            Type valueType,
            MethodInfo openGenericDeserialize,
            object target = null)
        {
            if (openGenericDeserialize == null) throw new ArgumentNullException(nameof(openGenericDeserialize));
            var closed = openGenericDeserialize.MakeGenericMethod(valueType);
            var p = Expression.Parameter(typeof(byte[]), "b");
            Expression call = closed.IsStatic
                ? Expression.Call(closed, p)
                : Expression.Call(Expression.Constant(target), closed, p);
            return Expression.Lambda<Func<byte[], object>>(
                Expression.Convert(call, typeof(object)), p).Compile();
        }

        public static Action<object, System.IO.Stream> BindSerializeStream(
            Type valueType,
            MethodInfo openGenericSerialize,
            object target = null)
        {
            var closed = openGenericSerialize.MakeGenericMethod(valueType);
            var po = Expression.Parameter(typeof(object), "o");
            var ps = Expression.Parameter(typeof(System.IO.Stream), "s");
            var cast = Expression.Convert(po, valueType);
            Expression call = closed.IsStatic
                ? Expression.Call(closed, cast, ps)
                : Expression.Call(Expression.Constant(target), closed, cast, ps);
            return Expression.Lambda<Action<object, System.IO.Stream>>(call, po, ps).Compile();
        }

        public static Func<System.IO.Stream, object> BindDeserializeStream(
            Type valueType,
            MethodInfo openGenericDeserialize,
            object target = null)
        {
            var closed = openGenericDeserialize.MakeGenericMethod(valueType);
            var ps = Expression.Parameter(typeof(System.IO.Stream), "s");
            Expression call = closed.IsStatic
                ? Expression.Call(closed, ps)
                : Expression.Call(Expression.Constant(target), closed, ps);
            return Expression.Lambda<Func<System.IO.Stream, object>>(
                Expression.Convert(call, typeof(object)), ps).Compile();
        }

        /// <summary>
        /// Collect nested public property/field types for serializers that need a closed type graph
        /// (e.g. NetSerializer). Domain-agnostic graph walk.
        /// </summary>
        public static Type[] CollectGraphTypes(Type root, params Type[] extra)
        {
            var set = new HashSet<Type>();
            var q = new Queue<Type>();
            void Enq(Type t)
            {
                if (t == null || t.IsPrimitive || t == typeof(string) || t == typeof(decimal)
                    || t == typeof(DateTime) || t == typeof(DateTimeOffset) || t == typeof(Guid)
                    || t.IsEnum) return;
                if (t.IsArray) { Enq(t.GetElementType()); return; }
                if (t.IsGenericType)
                {
                    foreach (var a in t.GetGenericArguments()) Enq(a);
                }
                if (!set.Add(t)) return;
                q.Enqueue(t);
            }
            Enq(root);
            foreach (var e in extra ?? Array.Empty<Type>()) Enq(e);
            while (q.Count > 0)
            {
                var t = q.Dequeue();
                foreach (var p in t.GetProperties(BindingFlags.Public | BindingFlags.Instance))
                {
                    if (p.GetIndexParameters().Length > 0) continue;
                    Enq(p.PropertyType);
                }
                foreach (var f in t.GetFields(BindingFlags.Public | BindingFlags.Instance))
                    Enq(f.FieldType);
            }
            return set.ToArray();
        }
    }
}
