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
        private readonly TelemetryData _data = TelemetryData.Generate(Randomizer.Settings.CollectionOptions.TelemetryMeasurementsCount);

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
        [ProtoMember(8)] [DataMember] [Id(7)] public long AssociatedLogID { get; set; }

        [ProtoMember(7)] [DataMember] [Id(6)] public long AssociatedProblemID { get; set; }

        [ProtoMember(2)] [DataMember] [Id(1)] public string DataSource { get; set; }

        [ProtoMember(1)] [DataMember] [Id(0)] public string Id { get; set; }

        [ProtoMember(6)] [DataMember] [Id(5)] public double[] Measurements { get; set; }

        [ProtoMember(4)] [DataMember] [Id(3)] public int Param1 { get; set; }

        [ProtoMember(5)] [DataMember] [Id(4)] public uint Param2 { get; set; }

        [ProtoMember(3)] [DataMember] [Id(2), Type(typeof (long))] public DateTime TimeStamp { get; set; }

        [ProtoMember(9)] [DataMember] [Id(8)] public bool WasProcessed { get; set; }

        public static TelemetryData Generate(int measurementsNumber)
        {
            var data = new TelemetryData
            {
                Id = Randomizer.Id,
                DataSource = Randomizer.Id,
                TimeStamp = DateTime.Now,
                Param1 = Randomizer.Rand.Next(int.MinValue, int.MaxValue),
                Param2 = (uint) Randomizer.Rand.Next(0, int.MaxValue),
                Measurements = new double[measurementsNumber],
                AssociatedProblemID = 123,
                AssociatedLogID = 89032,
                WasProcessed = true
            };
            for (var i = 0; i < measurementsNumber; i++)
                data.Measurements[i] = Randomizer.Rand.NextDouble();
            return data;
        }
    }
}