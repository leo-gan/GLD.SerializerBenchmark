using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using Bond;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using NFX;
using NFX.Parsing;
using ProtoBuf;

namespace GLD.SerializerBenchmark.TestData
{
    /// <summary>
    ///     This Test shows a batching scenario i.e. a full-duplex socket connection
    ///     when a party needs to send X consequitive atomic messages one after another in batches
    /// </summary>
    public class MsgBatchingDescription : ITestDataDescription
    {
        private readonly MsgBatching _data = MsgBatching.Generate(10, MsgBatchingType.RPC);

        public string Name
        {
            get { return "MsgBatching"; }
        }

        public string Description
        {
            get { return ""; }
        }

        public Type DataType
        {
            get { return typeof (MsgBatching); }
        }

        public List<Type> SecondaryDataTypes
        {
            get
            {
                return new List<Type>
                {
                    typeof (AddressMessage),
                    typeof (BankMsg),
                    typeof (MsgBatchingType),
                    typeof (RPCMessage),
                    typeof (SomePersonalDataMessage),
                    typeof (TradingRec)
                };
            }
        }

        public object Data
        {
            get { return _data; }
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class MsgBatching
    {
        [ProtoMember(3)] [DataMember] [Id(0)] public List<object> Data = new List<object>();
        [ProtoMember(1)] [DataMember] [Id(1)] public int MsgCount;
        [ProtoMember(2)] [DataMember] [Id(2)] public MsgBatchingType MsgType;

        public static MsgBatching Generate(int msgCount, MsgBatchingType msgType)
        {
            var msg = new MsgBatching
            {
                MsgCount = msgCount < 1 ? 1 : msgCount,
                MsgType = msgType
            };
            msg.Data = new List<object>(msg.MsgCount);

            for (var i = 0; i < msg.MsgCount; i++)
                msg.Data.Add(msg.MsgType == MsgBatchingType.Personal
                    ? SomePersonalDataMessage.Generate()
                    : msg.MsgType == MsgBatchingType.RPC
                        ? RPCMessage.Generate()
                        : msg.MsgType == MsgBatchingType.Trading
                            ? (object) TradingRec.Generate()
                            : EDI_X12_835.Generate()
                    );
            return msg;
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class AddressMessage
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string Address1;
        [ProtoMember(2)] [DataMember] [Id(1)] public string Address2;
        [ProtoMember(6)] [DataMember] [Id(2)] public bool CanAcceptSecureShipments;
        [ProtoMember(10)] [DataMember] [Id(3)] public string CellPhone;
        [ProtoMember(3)] [DataMember] [Id(4)] public string City;

        [ProtoMember(7)] [DataMember] [Id(5)] public string EMail;
        [ProtoMember(11)] [DataMember] [Id(6)] public string Fax;
        [ProtoMember(8)] [DataMember] [Id(7)] public string HomePhone;
        [ProtoMember(5)] [DataMember] [Id(8)] public string PostalCode;
        [ProtoMember(4)] [DataMember] [Id(9)] public string State;
        [ProtoMember(9)] [DataMember] [Id(10)] public string WorkPhone;

        public static AddressMessage Generate()
        {
            var rnd = ExternalRandomGenerator.Instance.NextRandomInteger;
            return new AddressMessage
            {
                Address1 = NaturalTextGenerator.GenerateAddressLine(),
                Address2 = (0 != (rnd & (1 << 15))) ? NaturalTextGenerator.GenerateAddressLine() : null,
                City = NaturalTextGenerator.GenerateCityName(),
                State = NaturalTextGenerator.GenerateCityName(),
                PostalCode = rnd.ToString(),
                CanAcceptSecureShipments = rnd > 0,
                EMail = rnd < -500000000 ? NaturalTextGenerator.GenerateEMail() : null,
                HomePhone = (0 != (rnd & (1 << 32))) ? "(555) 111-22234" : null,
                CellPhone = (0 != (rnd & (1 << 31))) ? "(555) 234-22234" : null,
                Fax = (0 != (rnd & (1 << 30))) ? "(555) 111-22239" : null
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class SomePersonalDataMessage
    {
        [ProtoMember(23)] [DataMember] [Id(0)] public decimal AssetsAtHand;
        [ProtoMember(7)] [DataMember] [Id(1)] public AddressMessage Billing;
        [ProtoMember(26)] [DataMember] [Id(2)] public double CreditScale;
        [ProtoMember(21)] [DataMember] [Id(3)] public int? EducationGrade;
        [ProtoMember(17)] [DataMember] [Id(4)] public bool? FirearmLicense;
        [ProtoMember(18)] [DataMember] [Id(5)] public bool? FishermanLicense;
        [ProtoMember(1)] [DataMember] [Id(6)] public Guid ID;
        [ProtoMember(2)] [DataMember] [Id(7)] public HumanName LegalName;
        [ProtoMember(22)] [DataMember] [Id(8)] public double? PossibleRiskFactor;
        [ProtoMember(24)] [DataMember] [Id(9)] public decimal PotentialAssets;

        [ProtoMember(16)] [DataMember] [Id(10)] public bool? RegisteredToVote;
        [ProtoMember(4)] [DataMember] [Id(11)] public DateTime RegistrationDate;
        [ProtoMember(3)] [DataMember] [Id(12)] public HumanName RegistrationName;

        [ProtoMember(8)] [DataMember] [Id(13)] public bool? Reserved_BoolFlag1;
        [ProtoMember(9)] [DataMember] [Id(14)] public bool? Reserved_BoolFlag2;
        [ProtoMember(12)] [DataMember] [Id(15)] public double? Reserved_DblFlag1;
        [ProtoMember(13)] [DataMember] [Id(16)] public double? Reserved_DblFlag2;
        [ProtoMember(10)] [DataMember] [Id(17)] public int? Reserved_IntFlag1;
        [ProtoMember(11)] [DataMember] [Id(18)] public int? Reserved_IntFlag2;
        [ProtoMember(5)] [DataMember] [Id(19)] public AddressMessage Residence;
        [ProtoMember(6)] [DataMember] [Id(20)] public AddressMessage Shipping;
        [ProtoMember(15)] [DataMember] [Id(21)] public byte[] SpeakerAccessCode;

        [ProtoMember(14)] [DataMember] [Id(22)] public byte[] StageAccessCode;
        [ProtoMember(25)] [DataMember] [Id(23)] public decimal TotalDebt;
        [ProtoMember(20)] [DataMember] [Id(24)] public int? YearsInSchool;
        [ProtoMember(19)] [DataMember] [Id(25)] public int? YearsInTheMilitary;


        public static SomePersonalDataMessage Generate()
        {
            var rnd = ExternalRandomGenerator.Instance.NextRandomInteger;
            var primaryAddr = AddressMessage.Generate();
            var data = new SomePersonalDataMessage
            {
                ID = Guid.NewGuid(),
                LegalName = HumanName.Build(),
                RegistrationName = HumanName.Build(),
                RegistrationDate = DateTime.Now.AddDays(-23),
                Residence = primaryAddr,
                Shipping = primaryAddr,
                Billing = primaryAddr,
                StageAccessCode = new byte[32],
                SpeakerAccessCode = new byte[32],
                YearsInSchool = (0 != (rnd & (1 << 29))) ? 10 : (int?) null,
                EducationGrade = (0 != (rnd & (1 << 28))) ? 230 : (int?) null,
                AssetsAtHand = 567000m,
                TotalDebt = 2345m,
                CreditScale = 0.02323d
            };

            return data;
        }
    }


    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class BankMsg
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string FIPSCode;
        [ProtoMember(2)] [DataMember] [Id(1)] public string HCFACode;
        [ProtoMember(4)] [DataMember] [Id(2)] public bool IsChargeable;
        [ProtoMember(3)] [DataMember] [Id(3)] public long LANGRARCode;

        public static BankMsg Generate()
        {
            var rnd = ExternalRandomGenerator.Instance.NextRandomInteger;
            return new BankMsg
            {
                FIPSCode = NaturalTextGenerator.Generate(20),
                HCFACode = NaturalTextGenerator.Generate(20),
                LANGRARCode = 1239872633238L,
                IsChargeable = true
            };
        }
    }


    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class RPCMessage
    {
        //Protobuf can not do it
        //http://stackoverflow.com/questions/25141791/serialize-object-with-protobuf-net
        //Can not support primitives, can not support byte[]
        //http://stackoverflow.com/questions/17192702/protobuf-net-serializing-system-object-with-dynamictype-throws-exception

        //http://stackoverflow.com/questions/11762851/protobuf-net-a-reference-tracked-object-changed-reference-during-deserializarti
        // '... A warning though: you mention "subclasses"; DynamicType does not play nicely with inheritance at the moment;
        // I have some outstanding work to do there.' –  Marc Gravell♦ Aug 2 '12 at 7:22 

        [ProtoMember(9, DynamicType = true)] [DataMember] [Id(0)] public object[] CallArguments;
        [ProtoMember(8)] [DataMember] [Id(1)] public bool ElevatePermission;
        [ProtoMember(4)] [DataMember] [Id(2)] public int MethodID;
        [ProtoMember(3)] [DataMember] [Id(3)] public string MethodName;
        [ProtoMember(5)] [DataMember] [Id(4)] public Guid? RemoteInstance;
        [ProtoMember(1)] [DataMember] [Id(5)] public Guid RequestID;
        [ProtoMember(6)] [DataMember] [Id(6)] public double? RequiredReliability;
        [ProtoMember(2)] [DataMember] [Id(7)] public string TypeName;
        [ProtoMember(7)] [DataMember] [Id(8)] public bool WrapException;

        public static RPCMessage Generate()
        {
            var rnd = ExternalRandomGenerator.Instance.NextRandomInteger;
            var msg = new RPCMessage
            {
                RequestID = Guid.NewGuid(),
                TypeName = NaturalTextGenerator.Generate(80),
                MethodName = NaturalTextGenerator.Generate(30),
                MethodID = rnd%25,
                RemoteInstance = (0 != (rnd & (1 << 32))) ? Guid.NewGuid() : (Guid?) null,
                RequiredReliability = (0 != (rnd & (1 << 31))) ? rnd/100d : (double?) null,
                WrapException = (0 != (rnd & (1 << 30))),
                ElevatePermission = (0 != (rnd & (1 << 29)))
            };

            msg.CallArguments = new object[ExternalRandomGenerator.Instance.NextScaledRandomInteger(0, 6)];
            for (var i = 0; i < msg.CallArguments.Length; i++)
            {
                var r = ExternalRandomGenerator.Instance.NextScaledRandomInteger(0, 4);
                if (r == 1) msg.CallArguments[i] = BankMsg.Generate();
                else if (r == 2) msg.CallArguments[i] = NaturalTextGenerator.Generate();
                else if (r == 3)
                    msg.CallArguments[i] = null; //new byte[16]; Protobuf does not support byte[] via object[]
                else
                    msg.CallArguments[i] = AddressMessage.Generate();
            }

            return msg;
        }
    }


    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class TradingRec
    {
        [ProtoMember(3)] [DataMember] [Id(0)] public long Bet;
        [ProtoMember(4)] [DataMember] [Id(1)] public long Price;
        [ProtoMember(1)] [DataMember] [Id(2)] public string Symbol;
        [ProtoMember(2)] [DataMember] [Id(3)] public int Volume;

        public static TradingRec Generate()
        {
            return new TradingRec
            {
                Symbol = NaturalTextGenerator.GenerateFirstName(),
                Volume = ExternalRandomGenerator.Instance.NextScaledRandomInteger(-25000, 25000),
                Bet = ExternalRandomGenerator.Instance.NextScaledRandomInteger(-250000, 250000)*10000L,
                Price = ExternalRandomGenerator.Instance.NextScaledRandomInteger(0, 1000000)*10000L
            };
        }
    }


    [DataContract]
    [JsonConverter(typeof (StringEnumConverter))]
    [Serializable]
    public enum MsgBatchingType
    {
        [EnumMember] Personal = 0,
        [EnumMember] RPC,
        [EnumMember] Trading,
        [EnumMember] EDI
    }
}