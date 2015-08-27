using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using Bond;
using NFX;
using ProtoBuf;

namespace GLD.SerializerBenchmark.TestData
{
    public class SimpleObjectDescription : ITestDataDescription
    {
        private readonly SimleObject _data = SimleObject.Generate();

        public string Name
        {
            get { return "Simple Object"; }
        }

        public string Description
        {
            get { return "Plain object with numbers and IDs, no arrays."; }
        }

        public Type DataType
        {
            get { return typeof (SimleObject); }
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

    [Schema]
    [ProtoContract]
    [DataContract]
    [Serializable]
    public class SimleObject
    {
        [Id(7)] [ProtoMember(8)] [DataMember] public long AssociatedLogID;

        [Id(6)] [ProtoMember(7)] [DataMember] public long AssociatedProblemID;

        [ProtoMember(2)] [DataMember] [Id(1)] public string DataSource;

        ///// <summary>
        ///// Required by some serilizers (i.e. XML)
        ///// </summary>
        //public SimleObject() { }       


        [ProtoMember(1)] [DataMember] [Id(0)] public string Id;

        [Id(5)] [ProtoMember(6)] [DataMember] public double Measurement;

        [Id(3)] [ProtoMember(4)] [DataMember] public int Param1;

        [Id(4)] [ProtoMember(5)] [DataMember] public uint Param2;

        [ProtoMember(3)] [DataMember] [Id(2), Type(typeof (long))] public DateTime TimeStamp;

        [Id(8)] [ProtoMember(9)] [DataMember] public bool WasProcessed;

        public static SimleObject Generate()
        {
            return new SimleObject
            {
                Id = Guid.NewGuid().ToString(),
                DataSource = Guid.NewGuid().ToString(),
                TimeStamp = DateTime.Now,
                Param1 = ExternalRandomGenerator.Instance.NextRandomInteger,
                Param2 = (uint) ExternalRandomGenerator.Instance.NextRandomInteger,
                Measurement = ExternalRandomGenerator.Instance.NextRandomDouble,
                AssociatedProblemID = 123,
                AssociatedLogID = 89032,
                WasProcessed = true
            };
        }
    }
}