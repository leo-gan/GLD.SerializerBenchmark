using System;
using System.Collections.Generic;
using NFX.Parsing;

namespace GLD.SerializerBenchmark.TestData
{
    public class StringArrayDescription : ITestDataDescription
    {
       private static string[] Generate(int arraySize)
       {
            var array = new string[arraySize];
           for (var index = 0; index < array.Length; index++)
               array[index] = NaturalTextGenerator.GenerateFirstName();
           return array;
       }

        public string Name
        {
            get { return "String Array"; }
        }

        public string Description
        {
            get { return "Simple string[]."; }
        }

        public Type DataType
        {
            get { return typeof (string[]); }
        }

        public List<Type> SecondaryDataTypes
        {
            get { return new List<Type>(); }
        }

        public object Data
        {
            get { return Generate(20); }
        }
    }
}