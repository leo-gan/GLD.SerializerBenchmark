using System;
using System.Linq;

namespace GLD.SerializerBenchmark.TestData
{
    public static class ZeroFormatterTypeConverter
    {
        public static ZFmt.SimpleObject ToZeroFormatter(SimpleObject obj)
        {
            if (obj == null) return null;
            return new ZFmt.SimpleObject
            {
                Id = obj.Id,
                Name = obj.Name,
                Timestamp = obj.Timestamp,
                IsActive = obj.IsActive
            };
        }

        public static SimpleObject FromZeroFormatter(ZFmt.SimpleObject obj)
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

        public static ZFmt.StringArrayObject ToZeroFormatter(StringArrayObject obj)
        {
            if (obj == null) return null;
            return new ZFmt.StringArrayObject { Items = obj.Items.ToList() };
        }

        public static StringArrayObject FromZeroFormatter(ZFmt.StringArrayObject obj)
        {
            if (obj == null) return null;
            return new StringArrayObject { Items = obj.Items.ToList() };
        }

        public static ZFmt.IntObject ToZeroFormatter(int value)
        {
            return new ZFmt.IntObject { Value = value };
        }

        public static int FromZeroFormatter(ZFmt.IntObject obj)
        {
            return obj?.Value ?? 0;
        }
    }
}
