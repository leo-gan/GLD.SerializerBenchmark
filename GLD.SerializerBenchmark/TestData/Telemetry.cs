using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using Bond;
using NFX;
using ProtoBuf;

namespace GLD.SerializerBenchmark.TestData
{
    public class TelemetryDescription : ITestDataDescription
    {
        private readonly TelemetryData _data = TelemetryData.Generate(100);

        public string Name
        {
            get { return "Telemetry"; }
        }

        public string Description
        {
            get { return "Plain object with numbers, IDs, and double[]"; }
        }

        public Type DataType
        {
            get { return typeof (TelemetryData); }
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

    [ProtoContract]
    [DataContract]
    [Serializable]
    [Schema]
    public class TelemetryData
    {
        [ProtoMember(8)] [DataMember] [Id(7)] public long AssociatedLogID;

        [ProtoMember(7)] [DataMember] [Id(6)] public long AssociatedProblemID;

        [ProtoMember(2)] [DataMember] [Id(1)] public string DataSource;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Id;

        [ProtoMember(6)] [DataMember] [Id(5)] public double[] Measurements;

        [ProtoMember(4)] [DataMember] [Id(3)] public int Param1;

        [ProtoMember(5)] [DataMember] [Id(4)] public uint Param2;

        [ProtoMember(3)] [DataMember] [Id(2), Type(typeof (long))] public DateTime TimeStamp;

        [ProtoMember(9)] [DataMember] [Id(8)] public bool WasProcessed;

        public static TelemetryData Generate(int measurementsNumber)
        {
            var data = new TelemetryData
            {
                Id = Guid.NewGuid().ToString(),
                DataSource = Guid.NewGuid().ToString(),
                TimeStamp = DateTime.Now,
                Param1 = ExternalRandomGenerator.Instance.NextRandomInteger,
                Param2 = (uint) ExternalRandomGenerator.Instance.NextRandomInteger,
                Measurements = new double[measurementsNumber],
                AssociatedProblemID = 123,
                AssociatedLogID = 89032,
                WasProcessed = true
            };
            for (var i = 0; i < measurementsNumber; i++)
                data.Measurements[i] = ExternalRandomGenerator.Instance.NextRandomDouble;
            return data;
        }
    }
}