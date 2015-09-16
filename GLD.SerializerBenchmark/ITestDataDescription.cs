using System;
using System.Collections.Generic;

namespace GLD.SerializerBenchmark
{
    public interface ITestDataDescription
    {
        string Name { get; }
        string Description { get; }
        Type DataType { get; }
        List<Type> SecondaryDataTypes { get; }
        object Data { get; }
    }
}