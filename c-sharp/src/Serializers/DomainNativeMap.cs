using System;
using System.Collections.Generic;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Suite-domain ↔ library-native binding. Implemented outside serializer wrappers
    /// (e.g. under TestData.V2.Maps) so wrappers never reference suite types.
    /// </summary>
    internal interface IDomainNativeMap
    {
        DomainNativeBinding Resolve(Type domainRootType);
    }

    internal sealed class DomainNativeBinding
    {
        public Type NativeRoot { get; init; }
        public IReadOnlyList<Type> NativeSecondary { get; init; } = Array.Empty<Type>();
        public Func<object, object> ToNative { get; init; }
        public Func<object, object> ToDomain { get; init; }
    }
}
