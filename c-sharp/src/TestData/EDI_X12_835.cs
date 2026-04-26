using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using ProtoBuf;
using Bond;

namespace GLD.SerializerBenchmark.TestData
{
    public class EDI_X12_835Description : ITestDataDescription
    {
        private readonly EDI835 _data = EDI835.Generate();

        public string Name => "EDI_835";
        public string Description => "Represents a complex Health Care Claim Payment/Advice (X12 835) document.";
        public Type DataType => typeof(EDI835);
        public List<Type> SecondaryDataTypes => new List<Type> { typeof(Claim), typeof(ServiceLine) };
        public object Data => _data;
    }

    [ProtoContract] [DataContract] [Serializable] [Schema]
    public class EDI835
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string PayerName { get; set; }
        [ProtoMember(2)] [DataMember] [Id(1)] public string PayeeName { get; set; }
        [ProtoMember(3)] [DataMember] [Id(2), Type(typeof(long))] public DateTime PaymentDate { get; set; }
        [ProtoMember(4)] [DataMember] [Id(3)] public double TotalActualAmount { get; set; }
        [ProtoMember(5)] [DataMember] [Id(4)] public string TransactionControlNumber { get; set; }
        [ProtoMember(6)] [DataMember] [Id(5)] public List<Claim> Claims { get; set; } = new List<Claim>();

        public static EDI835 Generate()
        {
            var doc = new EDI835
            {
                PayerName = "BlueCross BlueShield",
                PayeeName = "General Hospital",
                PaymentDate = DateTime.Now.AddDays(-1),
                TotalActualAmount = 1500.50,
                TransactionControlNumber = "TRN-99887766"
            };

            for (int i = 0; i < 5; i++)
            {
                var claim = new Claim
                {
                    ClaimId = "CLP-" + i,
                    PatientName = "Patient " + i,
                    TotalCharge = 300.00,
                    PaymentAmount = 250.00,
                };
                for (int j = 0; j < 3; j++)
                {
                    claim.Lines.Add(new ServiceLine
                    {
                        ServiceCode = "9921" + j,
                        ChargeAmount = 100.00,
                        AdjudicatedAmount = 80.00
                    });
                }
                doc.Claims.Add(claim);
            }
            return doc;
        }
    }

    [ProtoContract] [DataContract] [Serializable] [Schema]
    public class Claim
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string ClaimId { get; set; }
        [ProtoMember(2)] [DataMember] [Id(1)] public string PatientName { get; set; }
        [ProtoMember(3)] [DataMember] [Id(2)] public double TotalCharge { get; set; }
        [ProtoMember(4)] [DataMember] [Id(3)] public double PaymentAmount { get; set; }
        [ProtoMember(5)] [DataMember] [Id(4)] public List<ServiceLine> Lines { get; set; } = new List<ServiceLine>();
    }

    [ProtoContract] [DataContract] [Serializable] [Schema]
    public class ServiceLine
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string ServiceCode { get; set; }
        [ProtoMember(2)] [DataMember] [Id(1)] public double ChargeAmount { get; set; }
        [ProtoMember(3)] [DataMember] [Id(2)] public double AdjudicatedAmount { get; set; }
    }
}
