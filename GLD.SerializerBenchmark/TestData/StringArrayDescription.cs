using System;
using System.Collections.Generic;
using NFX;
using NFX.Parsing;

namespace GLD.SerializerBenchmark.TestData
{
    public class StringArrayDescription : ITestDataDescription
    {
       public string Name { get { return "String Array"; }}
       public string Description { get{ return "Simple string[]."; }}
      public Type DataType { get { return typeof (string[]); } }
        public List<Type> SecondaryDataTypes { get { return new List<Type>{}; } }

        private readonly string[] _data = 
        {
            NaturalTextGenerator.GenerateFirstName(),
            NaturalTextGenerator.GenerateFirstName(), 
            NaturalTextGenerator.GenerateFirstName(),
            NaturalTextGenerator.GenerateFirstName(),
        };

        public object Data { get { return _data; }  }
    }
}