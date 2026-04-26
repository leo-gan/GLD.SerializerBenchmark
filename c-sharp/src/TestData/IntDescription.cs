using System;
using System.Collections.Generic;

namespace GLD.SerializerBenchmark.TestData
{
    public class IntDescription : ITestDataDescription
    {
        private readonly int _data = Int32.MaxValue - 123;

        public string Name
        {
            get { return "Integer"; }
        }

        public string Description
        {
            get { return "Simple int (Int32)."; }
        }

        public Type DataType
        {
            get { return typeof (int); }
        }

        public List<Type> SecondaryDataTypes
        {
            get { return new List<Type>(); }
        }

        public object Data
        {
            get { return _data; }
        }
    }
}