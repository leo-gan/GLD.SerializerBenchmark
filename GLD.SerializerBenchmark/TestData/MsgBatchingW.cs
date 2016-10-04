using System;
using System.Collections.Generic;
using NFX;
using NFX.Parsing;

namespace GLD.SerializerBenchmark.TestDataW
{
    /// <summary>
    ///     This Test shows a batching scenario i.e. a full-duplex socket connection
    ///     when a party needs to send X consequitive atomic messages one after another in batches
    /// </summary>
    public class MsgBatchingW
    {
        public enum MsgBatchingType
        {
            Personal = 0,
            RPC,
            Trading,
            EDI
        }

        public List<object> Data = new List<object>();
        public int MsgCount;
        public MsgBatchingType MsgType;

        public static MsgBatchingW Generate(int msgCount, MsgBatchingType msgType)
        {
            var msgBatching = new MsgBatchingW();
            if (msgCount < 1) msgCount = 1;

            msgBatching.Data = new List<object>(msgCount);

            for (var i = 0; i < msgCount; i++)
                msgBatching.Data.Add(msgType == MsgBatchingType.Personal
                    ? SomePersonalDataMessage.Build()
                    : msgType == MsgBatchingType.RPC
                        ? RPCMessage.Generate()
                        : msgType == MsgBatchingType.Trading
                            ? (object) TradingRec.Generate()
                            : EDI_X12_835W.Generate()
                    );
            return msgBatching;
        }

        public class AddressMessage
        {
            public string Address1;
            public string Address2;
            public bool CanAcceptSecureShipments;
            public string CellPhone;
            public string City;

            public string EMail;
            public string Fax;
            public string HomePhone;
            public string PostalCode;
            public string State;
            public string WorkPhone;

            public static AddressMessage Build()
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

        public class SomePersonalDataMessage
        {
            public decimal AssetsAtHand;
            public AddressMessage Billing;
            public double CreditScale;
            public int? EducationGrade;
            public bool? FirearmLicense;
            public bool? FishermanLicense;
            public Guid ID;
            public HumanName LegalName;
            public double? PossibleRiskFactor;
            public decimal PotentialAssets;

            public bool? RegisteredToVote;
            public DateTime RegistrationDate;
            public HumanName RegistrationName;

            public bool? Reserved_BoolFlag1;
            public bool? Reserved_BoolFlag2;
            public double? Reserved_DblFlag1;
            public double? Reserved_DblFlag2;
            public int? Reserved_IntFlag1;
            public int? Reserved_IntFlag2;
            public AddressMessage Residence;
            public AddressMessage Shipping;
            public byte[] SpeakerAccessCode;

            public byte[] StageAccessCode;
            public decimal TotalDebt;
            public int? YearsInSchool;
            public int? YearsInTheMilitary;


            public static SomePersonalDataMessage Build()
            {
                var rnd = ExternalRandomGenerator.Instance.NextRandomInteger;
                var primaryAddr = AddressMessage.Build();
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


        public class BankMsg
        {
            public string FIPSCode;
            public string HCFACode;
            public bool IsChargeable;
            public long LANGRARCode;

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


        public class RPCMessage
        {
            public object[] CallArguments;
            public bool ElevatePermission;
            public int MethodID;
            public string MethodName;
            public Guid? RemoteInstance;
            public Guid RequestID;
            public double? RequiredReliability;
            public string TypeName;
            public bool WrapException;

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
                    ElevatePermission = (0 != (rnd & (1 << 29))),
                    CallArguments = new object[ExternalRandomGenerator.Instance.NextScaledRandomInteger(0, 6)]
                };

                for (var i = 0; i < msg.CallArguments.Length; i++)
                {
                    var r = ExternalRandomGenerator.Instance.NextScaledRandomInteger(0, 4);
                    switch (r)
                    {
                        case 1:
                            msg.CallArguments[i] = BankMsg.Generate();
                            break;
                        case 2:
                            msg.CallArguments[i] = NaturalTextGenerator.Generate();
                            break;
                        case 3:
                            msg.CallArguments[i] = null; //new byte[16]; Protobuf does not support byte via object
                            break;
                        default:
                            msg.CallArguments[i] = AddressMessage.Build();
                            break;
                    }
                }

                return msg;
            }
        }


        public class TradingRec
        {
            public long Bet;
            public long Price;
            public string Symbol;
            public int Volume;

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
    }
}