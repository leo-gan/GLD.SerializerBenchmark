using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using Bond;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using ProtoBuf;
using Serialization;

namespace GLD.SerializerBenchmark.TestData
{
    public class IntDescription : ITestDataDescription
    {
          public string Name { get { return "Integer"; }}
       public string Description { get{ return "Simple int (Int32)."; }}
      public Type DataType { get { return typeof (int); } }
        public List<Type> SecondaryDataTypes { get { return new List<Type>{}; } }

        private readonly int _data = 123;

        public object Data { get { return _data; }  }
    }



        //public static Person Generate()
        //{
        //    return new Person
        //    {
        //        FirstName = Randomizer.Name,
        //        LastName = Randomizer.Name,
        //        Age = (uint) Randomizer.Rand.Next(120),
        //        Gender = (Randomizer.Rand.Next(0, 1) == 0) ? Gender.Male : Gender.Female,
        //        Passport = new Passport
        //        {
        //            Authority = Randomizer.Phrase,
        //            ExpirationDate =
        //                Randomizer.GetDate(DateTime.UtcNow, DateTime.UtcNow + TimeSpan.FromDays(1000)),
        //            Number = Randomizer.Id
        //        },
        //        PoliceRecords = Enumerable.Range(0, 20).Select(i => new PoliceRecord
        //        {
        //            Id = i,
        //            CrimeCode = Randomizer.Name
        //        }).ToArray()
        //    };
        //}

}