using System;
using System.Collections.Generic;
using System.Linq;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Serializer that times codec work on a library-native graph. Domain↔native
    /// conversion is untimed via <see cref="IDomainNativeMap"/> (not suite-type switches).
    /// </summary>
    internal abstract class MappedSerDeser : SerDeser
    {
        private readonly IDomainNativeMap _map;
        protected DomainNativeBinding Binding { get; private set; }
        protected object NativePrepared { get; private set; }

        protected MappedSerDeser(IDomainNativeMap map)
            => _map = map ?? throw new ArgumentNullException(nameof(map));

        public override void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null)
        {
            Binding = _map.Resolve(serializablePrimaryType);
            var sec = Binding.NativeSecondary?.ToList() ?? new List<Type>();
            base.Initialize(Binding.NativeRoot, sec);
            OnNativeTypeReady(Binding.NativeRoot, sec);
        }

        public override void PrepareData(object data)
        {
            NativePrepared = Binding.ToNative(data);
            OnNativePrepared(NativePrepared);
        }

        public override object ToDomain(object decoded)
            => Binding.ToDomain(decoded);

        /// <summary>Timed path: prefer prepared native; else convert (should be rare).</summary>
        protected object NativeOf(object serializable)
            => NativePrepared ?? Binding.ToNative(serializable);

        protected virtual void OnNativeTypeReady(Type nativeRoot, List<Type> nativeSecondary) { }
        protected virtual void OnNativePrepared(object native) { }
    }
}
