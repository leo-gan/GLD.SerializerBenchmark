using System;
using System.Linq;

namespace GLD.SerializerBenchmark.TestData
{
    public static class MemoryPackTypeConverter
    {
        public static MPack.SimpleObject ToMemoryPack(SimpleObject obj)
        {
            if (obj == null) return null;
            return new MPack.SimpleObject
            {
                Id = obj.Id,
                Name = obj.Name,
                Timestamp = obj.Timestamp,
                IsActive = obj.IsActive
            };
        }

        public static SimpleObject FromMemoryPack(MPack.SimpleObject obj)
        {
            if (obj == null) return null;
            return new SimpleObject
            {
                Id = obj.Id,
                Name = obj.Name,
                Timestamp = obj.Timestamp,
                IsActive = obj.IsActive
            };
        }

        public static MPack.StringArrayObject ToMemoryPack(StringArrayObject obj)
        {
            if (obj == null) return null;
            return new MPack.StringArrayObject { Items = obj.Items.ToList() };
        }

        public static StringArrayObject FromMemoryPack(MPack.StringArrayObject obj)
        {
            if (obj == null) return null;
            return new StringArrayObject { Items = obj.Items.ToList() };
        }

        public static MPack.IntObject ToMemoryPack(int value)
        {
            return new MPack.IntObject { Value = value };
        }

        public static int FromMemoryPack(MPack.IntObject obj)
        {
            return obj?.Value ?? 0;
        }
    }
}
