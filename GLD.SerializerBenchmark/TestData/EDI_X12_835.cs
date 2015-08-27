using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using Bond;
using NFX;
using NFX.Parsing;
using ProtoBuf;

namespace GLD.SerializerBenchmark.TestData
{
    public class EDI_X12_835Description : ITestDataDescription
    {
        private readonly EDI_X12_835 _data = EDI_X12_835.Generate();

        public string Name
        {
            get { return "EDI_X12_835"; }
        }

        public string Description
        {
            get { return "A class with complex internal hierarchy."; }
        }

        public Type DataType
        {
            get { return typeof (EDI_X12_835); }
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
    [Schema]
    [Serializable]
    public abstract class Segment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string SegmentTag;

        public Segment(string segmentTag)
        {
            SegmentTag = segmentTag;
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class EDI_X12_835
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public BPR_FinancialInformation BPR_FinancialInformation;

        [ProtoMember(3)] [DataMember] [Id(2)] public CUR_ForeignCurrencyInformation CUR_ForeignCurrencyInformation;

        [ProtoMember(5)] [DataMember] [Id(4)] public DTM_Date DTM_ProductionDate;

        [ProtoMember(6)] [DataMember] [Id(5)] public N1_SubLoop N1_SubLoop;

        [ProtoMember(8)] [DataMember] [Id(7)] public List<PLB_ProviderAdjustment> PLB_ProviderAdjustmentList;

        [ProtoMember(4)] [DataMember] [Id(3)] public List<REF_SubLoop> REF_SubLoops;

        [ProtoMember(2)] [DataMember] [Id(1)] public TRN_ReassociationTraceNumber TRN_ReassociationTraceNumber;

        [ProtoMember(7)] [DataMember] [Id(6)] public TS835_2000_Loop TS835_2000_Loop;

        public static EDI_X12_835 Generate()
        {
            return new EDI_X12_835
            {
                BPR_FinancialInformation = BPR_FinancialInformation.Make(),
                TRN_ReassociationTraceNumber = TRN_ReassociationTraceNumber.Make(),
                CUR_ForeignCurrencyInformation = CUR_ForeignCurrencyInformation.Make(),
                REF_SubLoops = new List<REF_SubLoop> {REF_SubLoop.Make(), REF_SubLoop.Make(), REF_SubLoop.Make()},
                DTM_ProductionDate = DTM_Date.Make(),
                N1_SubLoop = N1_SubLoop.Make(),
                TS835_2000_Loop = TS835_2000_Loop.Make(),
                PLB_ProviderAdjustmentList = new List<PLB_ProviderAdjustment>
                {
                    PLB_ProviderAdjustment.Make(),
                    PLB_ProviderAdjustment.Make(),
                    PLB_ProviderAdjustment.Make(),
                    PLB_ProviderAdjustment.Make()
                }
            };
        }

        public static bool AssertPayloadEquality(object original, object deserialized, out string errorString)
        {
            errorString = null;

            if (original is IList<EDI_X12_835>)
                return deserialized != null && original.GetType() == deserialized.GetType();


            var originalTyped = original as EDI_X12_835;
            var deserializedTyped = deserialized as EDI_X12_835;

            if (originalTyped == null || deserializedTyped == null)
                errorString = "Error: originalTyped or deserializedType == null";
            else if (originalTyped.PLB_ProviderAdjustmentList.Count != deserializedTyped.PLB_ProviderAdjustmentList.Count)
                errorString = "Error: originalTyped.PLB_ProviderAdjustmentList.Count == deserializedTyped.PLB_ProviderAdjustmentList.Count ({0} != {1}"
                    .Args(
                        originalTyped.PLB_ProviderAdjustmentList.Count,
                        deserializedTyped.PLB_ProviderAdjustmentList.Count);
            else if (originalTyped.PLB_ProviderAdjustmentList[0].Reference_Identification
                     != deserializedTyped.PLB_ProviderAdjustmentList[0].Reference_Identification)
                errorString = "Error: originalTyped.PLB_ProviderAdjustmentList[0].Reference_Identification != deserializedTyped.PLB_ProviderAdjustmentList[0].Reference_Identification({0} != {1})"
                    .Args(
                        originalTyped.PLB_ProviderAdjustmentList[0].Reference_Identification,
                        deserializedTyped.PLB_ProviderAdjustmentList[0].Reference_Identification
                    );
            return (errorString == null) ? true : false;
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class AccoungInfo
    {
        [ProtoMember(4)] [DataMember] [Id(3)] public string Account_Number;

        [ProtoMember(3)] [DataMember] [Id(2)] public string Account_Number_Qualifier;

        [ProtoMember(2)] [DataMember] [Id(1)] public string DFI_Identification_Number;

        [ProtoMember(1)] [DataMember] [Id(0)] public string DFI_Number_Qualifier;

        public static AccoungInfo Make()
        {
            var result = new AccoungInfo();

            result.Account_Number = NaturalTextGenerator.GenerateWord();
            result.Account_Number_Qualifier = "Q";
            result.DFI_Identification_Number = ExternalRandomGenerator.Instance.NextRandomInteger.ToString();
            result.DFI_Number_Qualifier = "Q";

            return result;
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class BPR_FinancialInformation : Segment
    {
        [ProtoMember(6)] [DataMember] [Id(5)] public AccoungInfo AccoungInfo1;

        [ProtoMember(9)] [DataMember] [Id(8)] public AccoungInfo AccoungInfo2;

        [ProtoMember(11)] [DataMember] [Id(10)] public AccoungInfo AccoungInfo3;

        [ProtoMember(3)] [DataMember] [Id(1)] public int CreditDebit_Flag_Code;

        [ProtoMember(10)] [DataMember] [Id(9)] public string Date;

        [ProtoMember(7)] [DataMember] [Id(6)] public string Originating_Company_Identifier;

        [ProtoMember(8)] [DataMember] [Id(7)] public string Originating_Company_Supplemental_Code;

        [ProtoMember(5)] [DataMember] [Id(4)] public string Payment_Format_Code;

        [ProtoMember(4)] [DataMember] [Id(2)] public decimal Payment_Method_Code;

        [ProtoMember(2)] [DataMember] [Id(0)] public int TransactionHandlingCode;

        public BPR_FinancialInformation()
            : base("BPR")
        {
        }


        public static BPR_FinancialInformation Make()
        {
            var result = new BPR_FinancialInformation();

            result.TransactionHandlingCode = ExternalRandomGenerator.Instance.NextRandomInteger;
            result.CreditDebit_Flag_Code = ExternalRandomGenerator.Instance.NextRandomInteger;
            result.CreditDebit_Flag_Code = ExternalRandomGenerator.Instance.AsInt();
            result.Payment_Format_Code = "CA";
            result.AccoungInfo1 = AccoungInfo.Make();
            result.Originating_Company_Identifier =
                result.Originating_Company_Supplemental_Code = "CSC";
            result.AccoungInfo2 = AccoungInfo.Make();
            result.Date = DateTime.Now.ToShortDateString();
            result.AccoungInfo3 = AccoungInfo.Make();

            return result;
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class TRN_ReassociationTraceNumber : Segment
    {
        [ProtoMember(4)] [DataMember] [Id(2)] public string Originatin_Company_Identifier;

        [ProtoMember(3)] [DataMember] [Id(1)] public string Reference_Identification;

        [ProtoMember(5)] [DataMember] [Id(3)] public string Reference_Identification2;

        [ProtoMember(2)] [DataMember] [Id(0)] public string Trace_Type_Code;

        public TRN_ReassociationTraceNumber()
            : base("TRN")
        {
        }

        public static TRN_ReassociationTraceNumber Make()
        {
            return new TRN_ReassociationTraceNumber
            {
                Trace_Type_Code = "TT",
                Reference_Identification = NaturalTextGenerator.GenerateWord(),
                Originatin_Company_Identifier = NaturalTextGenerator.GenerateWord(),
                Reference_Identification2 = NaturalTextGenerator.GenerateWord()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class CUR_DateTime
    {
        [ProtoMember(2)] [DataMember] [Id(1)] public string Date;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Qualifier;

        [ProtoMember(3)] [DataMember] [Id(2)] public string Time;

        public static CUR_DateTime Make()
        {
            return new CUR_DateTime
            {
                Qualifier = "Q",
                Date = DateTime.Now.ToShortDateString(),
                Time = DateTime.Now.ToShortTimeString()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class CUR_ForeignCurrencyInformation : Segment
    {
        [ProtoMember(7)] [DataMember] [Id(6)] public List<CUR_DateTime> CUR_DateTimes;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Currency_Code;

        [ProtoMember(5)] [DataMember] [Id(4)] public string Currency_Code2;

        [ProtoMember(6)] [DataMember] [Id(5)] public string Currency_Market_Exchange_Code;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Entity_Identifier_Code;

        [ProtoMember(4)] [DataMember] [Id(3)] public string Entity_Identifier_Code2;

        [ProtoMember(3)] [DataMember] [Id(2)] public string Exchange_Rate;

        public CUR_ForeignCurrencyInformation() : base("CUR")
        {
        }

        public static CUR_ForeignCurrencyInformation Make()
        {
            return new CUR_ForeignCurrencyInformation
            {
                Entity_Identifier_Code = "CU",
                Currency_Code = "CAD",
                Exchange_Rate = "1.25",
                Entity_Identifier_Code2 = NaturalTextGenerator.Generate(3),
                Currency_Code2 = "USD",
                Currency_Market_Exchange_Code = "FX",
                CUR_DateTimes = new List<CUR_DateTime>
                {
                    CUR_DateTime.Make(),
                    CUR_DateTime.Make(),
                    CUR_DateTime.Make(),
                    CUR_DateTime.Make(),
                    CUR_DateTime.Make(),
                    CUR_DateTime.Make(),
                    CUR_DateTime.Make(),
                    CUR_DateTime.Make()
                }
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class REF_SubLoop
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public REF_Identification REF_ReceiverIdentification;

        [ProtoMember(2)] [DataMember] [Id(1)] public REF_Identification REF_VersionIdentification;

        public static REF_SubLoop Make()
        {
            return new REF_SubLoop
            {
                REF_ReceiverIdentification = REF_Identification.Make(),
                REF_VersionIdentification = REF_Identification.Make()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class REF_Identification : Segment
    {
        [ProtoMember(3)] [DataMember] [Id(2)] public string Description;

        [ProtoMember(4)] [DataMember] [Id(3)] public string Description2;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Reference_Identification;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Reference_Identification_Qualifier;

        public REF_Identification() : base("REF")
        {
        }

        public static REF_Identification Make()
        {
            return new REF_Identification
            {
                Reference_Identification_Qualifier = "RF",
                Reference_Identification = NaturalTextGenerator.GenerateWord(),
                Description = NaturalTextGenerator.Generate(50),
                Description2 = NaturalTextGenerator.Generate(20)
            };
        }
    }


    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class DTM_Date : Segment
    {
        [ProtoMember(2)] [DataMember] [Id(1)] public string Date;

        [ProtoMember(6)] [DataMember] [Id(5)] public string Date_Time_Period;

        [ProtoMember(5)] [DataMember] [Id(4)] public string Date_Time_Period_Format_Qualifier;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Date_Time_Qualifier;

        [ProtoMember(3)] [DataMember] [Id(2)] public string Time;

        [ProtoMember(4)] [DataMember] [Id(3)] public string Time_Code;

        public DTM_Date() : base("DTM")
        {
        }

        public static DTM_Date Make()
        {
            return new DTM_Date
            {
                Date_Time_Qualifier = "DT",
                Date = DateTime.Now.ToShortDateString(),
                Time = DateTime.Now.ToShortTimeString(),
                Time_Code = "UTC",
                Date_Time_Period_Format_Qualifier = "D",
                Date_Time_Period = "M"
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class N1_SubLoop
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public TS835_1000A_Loop TS835_1000A_Loop;

        [ProtoMember(2)] [DataMember] [Id(1)] public TS835_1000B_Loop TS835_1000B_Loop;

        public static N1_SubLoop Make()
        {
            return new N1_SubLoop
            {
                TS835_1000A_Loop = TS835_1000A_Loop.Make(),
                TS835_1000B_Loop = TS835_1000B_Loop.Make()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class TS835_1000A_Loop
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public N1_PartyIdentification N1_PayerIdentification;

        [ProtoMember(2)] [DataMember] [Id(1)] public N3_PartyAddress N3_PayerAddress;

        [ProtoMember(3)] [DataMember] [Id(2)] public N4_PartyCity_State_ZIPCode N4_PayerCity_State_ZIPCode;

        [ProtoMember(5)] [DataMember] [Id(4)] public PER_SubLoop PER_SubLoop;

        [ProtoMember(4)] [DataMember] [Id(3)] public List<REF_AdditionalPartyIdentification>
            REF_AdditionalPayerIdentification_Loop;

        public static TS835_1000A_Loop Make()
        {
            return new TS835_1000A_Loop
            {
                N1_PayerIdentification = N1_PartyIdentification.Make(),
                N3_PayerAddress = N3_PartyAddress.Make(),
                N4_PayerCity_State_ZIPCode = N4_PartyCity_State_ZIPCode.Make(),
                REF_AdditionalPayerIdentification_Loop = new List<REF_AdditionalPartyIdentification>
                {
                    REF_AdditionalPartyIdentification.Make(),
                    REF_AdditionalPartyIdentification.Make(),
                    REF_AdditionalPartyIdentification.Make()
                },
                PER_SubLoop = PER_SubLoop.Make()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class TS835_1000B_Loop
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public N1_PartyIdentification N1_PayeeIdentification;

        [ProtoMember(2)] [DataMember] [Id(1)] public N3_PartyAddress N3_PayeeAddress;

        [ProtoMember(3)] [DataMember] [Id(2)] public N4_PartyCity_State_ZIPCode N4_PayeeCity_State_ZIPCode;

        [ProtoMember(5)] [DataMember] [Id(4)] public RDM_RemittanceDeliveryMethod RDM_RemittanceDeliveryMethod;

        [ProtoMember(4)] [DataMember] [Id(3)] public List<REF_AdditionalPartyIdentification>
            REF_PayeeAdditionalIdentification;

        public static TS835_1000B_Loop Make()
        {
            return new TS835_1000B_Loop
            {
                N1_PayeeIdentification = N1_PartyIdentification.Make(),
                N3_PayeeAddress = N3_PartyAddress.Make(),
                N4_PayeeCity_State_ZIPCode = N4_PartyCity_State_ZIPCode.Make(),
                REF_PayeeAdditionalIdentification =
                    new List<REF_AdditionalPartyIdentification>
                    {
                        REF_AdditionalPartyIdentification.Make(),
                        REF_AdditionalPartyIdentification.Make(),
                        REF_AdditionalPartyIdentification.Make()
                    },
                RDM_RemittanceDeliveryMethod = RDM_RemittanceDeliveryMethod.Make()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class N1_PartyIdentification : Segment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string Entity_Identifier_Code;

        [ProtoMember(6)] [DataMember] [Id(5)] public string Entity_Identifier_Code2;

        [ProtoMember(5)] [DataMember] [Id(4)] public string Entity_Relationship_Code;

        [ProtoMember(4)] [DataMember] [Id(3)] public string Identification_Code;

        [ProtoMember(3)] [DataMember] [Id(2)] public string Identification_Code_Qualifier;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Name;

        public N1_PartyIdentification() : base("N1")
        {
        }

        public static N1_PartyIdentification Make()
        {
            return new N1_PartyIdentification
            {
                Entity_Identifier_Code = "TY",
                Name = NaturalTextGenerator.GenerateFullName(),
                Identification_Code_Qualifier = "CU",
                Identification_Code = NaturalTextGenerator.GenerateWord(),
                Entity_Relationship_Code = NaturalTextGenerator.GenerateWord(),
                Entity_Identifier_Code2 = NaturalTextGenerator.GenerateWord()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class N3_PartyAddress : Segment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string AddressInformation1;

        [ProtoMember(2)] [DataMember] [Id(1)] public string AddressInformation2;

        public N3_PartyAddress() : base("N3")
        {
        }

        public static N3_PartyAddress Make()
        {
            return new N3_PartyAddress
            {
                AddressInformation1 = NaturalTextGenerator.GenerateAddressLine(),
                AddressInformation2 = NaturalTextGenerator.GenerateUSCityStateZip()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class N4_PartyCity_State_ZIPCode : Segment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string City_Name;

        [ProtoMember(4)] [DataMember] [Id(3)] public string Country_Code;

        [ProtoMember(7)] [DataMember] [Id(6)] public string Country_Subdivision_Code;

        [ProtoMember(6)] [DataMember] [Id(5)] public string Location_Identifier;

        [ProtoMember(5)] [DataMember] [Id(4)] public string Location_Qualifier;

        [ProtoMember(3)] [DataMember] [Id(2)] public string Postal_Code;

        [ProtoMember(2)] [DataMember] [Id(1)] public string State_or_Province_Code;

        public N4_PartyCity_State_ZIPCode() : base("N4")
        {
        }

        public static N4_PartyCity_State_ZIPCode Make()
        {
            return new N4_PartyCity_State_ZIPCode
            {
                City_Name = NaturalTextGenerator.GenerateCityName(),
                State_or_Province_Code = "CA",
                Postal_Code = "98155",
                Country_Code = "USA",
                Location_Qualifier = "LA",
                Location_Identifier = "1234567.12",
                Country_Subdivision_Code = "WW"
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class REF_AdditionalPartyIdentification : Segment
    {
        [ProtoMember(3)] [DataMember] [Id(2)] public string Description;

        [ProtoMember(4)] [DataMember] [Id(3)] public string Description2;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Reference_Identification;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Reference_Identification_Qualifier;

        public REF_AdditionalPartyIdentification() : base("REF")
        {
        }

        public static REF_AdditionalPartyIdentification Make()
        {
            return new REF_AdditionalPartyIdentification
            {
                Reference_Identification_Qualifier = "QU",
                Reference_Identification = NaturalTextGenerator.GenerateWord(),
                Description = NaturalTextGenerator.Generate(70),
                Description2 = NaturalTextGenerator.Generate(30)
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class PER_SubLoop
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public PER_PartyContactInformation PER_PayerBusinessContactInformation;

        [ProtoMember(2)] [DataMember] [Id(1)] public List<PER_PartyContactInformation>
            PER_PayerTechnicalContactInformation;

        [ProtoMember(3)] [DataMember] [Id(2)] public PER_PartyContactInformation PER_PayerWEBSite;

        public static PER_SubLoop Make()
        {
            return new PER_SubLoop
            {
                PER_PayerBusinessContactInformation = PER_PartyContactInformation.Make(),
                PER_PayerTechnicalContactInformation = new List<PER_PartyContactInformation>
                {
                    PER_PartyContactInformation.Make(),
                    PER_PartyContactInformation.Make(),
                    PER_PartyContactInformation.Make(),
                    PER_PartyContactInformation.Make(),
                    PER_PartyContactInformation.Make()
                },
                PER_PayerWEBSite = PER_PartyContactInformation.Make()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class PER_PartyContactInformation : Segment
    {
        [ProtoMember(3)] [DataMember] [Id(2)] public CommunicationNumber CommunicationNumber1;

        [ProtoMember(4)] [DataMember] [Id(3)] public CommunicationNumber CommunicationNumber2;

        [ProtoMember(5)] [DataMember] [Id(4)] public CommunicationNumber CommunicationNumber3;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Contact_Function_Code;

        [ProtoMember(6)] [DataMember] [Id(5)] public string Contact_Inquiry_Reference;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Name;

        public PER_PartyContactInformation() : base("PER")
        {
        }

        public static PER_PartyContactInformation Make()
        {
            return new PER_PartyContactInformation
            {
                Contact_Function_Code = "RP",
                Name = NaturalTextGenerator.GenerateFirstName(),
                CommunicationNumber1 = CommunicationNumber.Make(),
                CommunicationNumber2 = CommunicationNumber.Make(),
                CommunicationNumber3 = CommunicationNumber.Make(),
                Contact_Inquiry_Reference = NaturalTextGenerator.GenerateWord()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class CommunicationNumber
    {
        [ProtoMember(2)] [DataMember] [Id(1)] public string Communication_Number;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Communication_Number_Qualifier;

        public static CommunicationNumber Make()
        {
            return new CommunicationNumber
            {
                Communication_Number_Qualifier = "QW",
                Communication_Number = NaturalTextGenerator.GenerateEMail()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class RDM_RemittanceDeliveryMethod : Segment
    {
        [ProtoMember(3)] [DataMember] [Id(2)] public string Communication_Number;

        [ProtoMember(4)] [DataMember] [Id(3)] public string Info1;

        [ProtoMember(5)] [DataMember] [Id(4)] public string Info2;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Name;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Report_Transmission_Code;

        public RDM_RemittanceDeliveryMethod() : base("RDM")
        {
        }

        public static RDM_RemittanceDeliveryMethod Make()
        {
            return new RDM_RemittanceDeliveryMethod
            {
                Report_Transmission_Code = NaturalTextGenerator.GenerateWord(),
                Name = NaturalTextGenerator.GenerateFullName(),
                Communication_Number = NaturalTextGenerator.GenerateEMail(),
                Info1 = NaturalTextGenerator.Generate(50),
                Info2 = NaturalTextGenerator.Generate(20)
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class TS835_2000_Loop
    {
        [ProtoMember(9)] [DataMember] [Id(8)] public List<AMT_ClaimSupplementalInformation>
            AMT_ClaimSupplementalInformations;

        [ProtoMember(7)] [DataMember] [Id(6)] public DTM_SubLoop DTM_SubLoop;

        [ProtoMember(1)] [DataMember] [Id(0)] public LX_HeaderNumber LX_HeaderNumber;

        [ProtoMember(5)] [DataMember] [Id(4)] public MIA_InpatientAdjudicationInformation
            MIA_InpatientAdjudicationInformation;

        [ProtoMember(6)] [DataMember] [Id(5)] public MOA_OutpatientAdjudicationInformation
            MOA_OutpatientAdjudicationInformation;

        [ProtoMember(8)] [DataMember] [Id(7)] public List<PER_ClaimContactInformation> PER_ClaimContactInformations;

        [ProtoMember(10)] [DataMember] [Id(9)] public List<QTY_ClaimSupplementalInformationQuantity>
            QTY_ClaimSupplementalInformationQuantities;

        [ProtoMember(3)] [DataMember] [Id(2)] public TS2_ProviderSupplementalSummaryInformation
            TS2_ProviderSupplementalSummaryInformation;

        [ProtoMember(2)] [DataMember] [Id(1)] public TS3_ProviderSummaryInformation TS3_ProviderSummaryInformation;

        [ProtoMember(4)] [DataMember] [Id(3)] public TS835_2100_Loop TS835_2100_Loop;

        [ProtoMember(11)] [DataMember] [Id(10)] public TS835_2110_Loop TS835_2110_Loop;

        public static TS835_2000_Loop Make()
        {
            return new TS835_2000_Loop
            {
                LX_HeaderNumber = LX_HeaderNumber.Make(),
                TS3_ProviderSummaryInformation = TS3_ProviderSummaryInformation.Make(),
                TS2_ProviderSupplementalSummaryInformation = TS2_ProviderSupplementalSummaryInformation.Make(),
                TS835_2100_Loop = TS835_2100_Loop.Make(),
                MIA_InpatientAdjudicationInformation = MIA_InpatientAdjudicationInformation.Make(),
                MOA_OutpatientAdjudicationInformation = MOA_OutpatientAdjudicationInformation.Make(),
                DTM_SubLoop = DTM_SubLoop.Make(),
                PER_ClaimContactInformations = new List<PER_ClaimContactInformation>
                {
                    PER_ClaimContactInformation.Make(),
                    PER_ClaimContactInformation.Make(),
                    PER_ClaimContactInformation.Make(),
                    PER_ClaimContactInformation.Make()
                },
                AMT_ClaimSupplementalInformations = new List<AMT_ClaimSupplementalInformation>
                {
                    AMT_ClaimSupplementalInformation.Make(),
                    AMT_ClaimSupplementalInformation.Make(),
                    AMT_ClaimSupplementalInformation.Make()
                },
                QTY_ClaimSupplementalInformationQuantities = new List<QTY_ClaimSupplementalInformationQuantity>
                {
                    QTY_ClaimSupplementalInformationQuantity.Make(),
                    QTY_ClaimSupplementalInformationQuantity.Make(),
                    QTY_ClaimSupplementalInformationQuantity.Make(),
                    QTY_ClaimSupplementalInformationQuantity.Make()
                },
                TS835_2110_Loop = TS835_2110_Loop.Make()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class LX_HeaderNumber : Segment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string Assigned_Number;

        public LX_HeaderNumber() : base("LX")
        {
        }

        public static LX_HeaderNumber Make()
        {
            return new LX_HeaderNumber
            {
                Assigned_Number = ExternalRandomGenerator.Instance.AsDecimal().ToString()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class TS3_ProviderSummaryInformation : Segment
    {
        [ProtoMember(3)] [DataMember] [Id(2)] public string Date;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Facility_Code_Value;

        [ProtoMember(5)] [DataMember] [Id(4)] public decimal Monetary_Amount;

        [ProtoMember(8)] [DataMember] [Id(7)] public decimal? Monetary_Amount2;

        [ProtoMember(6)] [DataMember] [Id(5)] public List<decimal> MonetaryAmountList;

        [ProtoMember(4)] [DataMember] [Id(3)] public decimal Quantity;

        [ProtoMember(7)] [DataMember] [Id(6)] public decimal? Quantity2;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Reference_Identification;

        public TS3_ProviderSummaryInformation() : base("TS3")
        {
        }

        public static TS3_ProviderSummaryInformation Make()
        {
            return new TS3_ProviderSummaryInformation
            {
                Reference_Identification = "OR",
                Facility_Code_Value = "Factory Code Value",
                Date = DateTime.Now.ToShortDateString(),
                Quantity = ExternalRandomGenerator.Instance.AsDecimal(),
                Monetary_Amount = ExternalRandomGenerator.Instance.AsDecimal(),
                MonetaryAmountList = new List<decimal>
                {
                    ExternalRandomGenerator.Instance.AsDecimal(),
                    ExternalRandomGenerator.Instance.AsDecimal(),
                    ExternalRandomGenerator.Instance.AsDecimal(),
                    ExternalRandomGenerator.Instance.AsDecimal(),
                    ExternalRandomGenerator.Instance.AsDecimal(),
                    ExternalRandomGenerator.Instance.AsDecimal()
                },
                Quantity2 = ExternalRandomGenerator.Instance.AsDecimal(),
                Monetary_Amount2 = ExternalRandomGenerator.Instance.AsDecimal()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class TS2_ProviderSupplementalSummaryInformation : Segment
    {
        [ProtoMember(3)] [DataMember] [Id(2)] public decimal? Monetary_Amount2;

        [ProtoMember(4)] [DataMember] [Id(3)] public decimal? Monetary_Amount3;

        [ProtoMember(1)] [DataMember] [Id(0)] public List<decimal> Monetary_AmountList;

        [ProtoMember(2)] [DataMember] [Id(1)] public decimal Quantity;

        public TS2_ProviderSupplementalSummaryInformation() : base("TS2")
        {
        }

        public static TS2_ProviderSupplementalSummaryInformation Make()
        {
            return new TS2_ProviderSupplementalSummaryInformation
            {
                Monetary_AmountList = new List<decimal>
                {
                    ExternalRandomGenerator.Instance.AsDecimal(),
                    ExternalRandomGenerator.Instance.AsDecimal(),
                    ExternalRandomGenerator.Instance.AsDecimal(),
                    ExternalRandomGenerator.Instance.AsDecimal()
                },
                Quantity = ExternalRandomGenerator.Instance.AsDecimal(),
                Monetary_Amount2 = ExternalRandomGenerator.Instance.AsDecimal()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class TS835_2100_Loop
    {
        [ProtoMember(2)] [DataMember] [Id(1)] public CAS_Adjustment CAS_ClaimsAdjustment;

        [ProtoMember(1)] [DataMember] [Id(0)] public CLP_ClaimPaymentInformation CLP_ClaimPaymentInformation;

        [ProtoMember(4)] [DataMember] [Id(3)] public MIA_InpatientAdjudicationInformation
            MIA_InpatientAdjudicationInformation;

        [ProtoMember(3)] [DataMember] [Id(2)] public NM1_SubLoop NM1_SubLoop;

        public static TS835_2100_Loop Make()
        {
            return new TS835_2100_Loop
            {
                CLP_ClaimPaymentInformation = CLP_ClaimPaymentInformation.Make(),
                CAS_ClaimsAdjustment = CAS_Adjustment.Make(),
                NM1_SubLoop = NM1_SubLoop.Make(),
                MIA_InpatientAdjudicationInformation = MIA_InpatientAdjudicationInformation.Make()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class CLP_ClaimPaymentInformation : Segment
    {
        [ProtoMember(6)] [DataMember] [Id(5)] public string Claim_Filing_Indicator_Code;

        [ProtoMember(9)] [DataMember] [Id(8)] public string Claim_Frequency_Type_Code;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Claim_Status_Code;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Claim_Submitters_Identifier;

        [ProtoMember(11)] [DataMember] [Id(10)] public string Diagnosis_Related_Group_DRG_Code;

        [ProtoMember(8)] [DataMember] [Id(7)] public string Facility_Code_Value;

        [ProtoMember(3)] [DataMember] [Id(2)] public decimal Monetary_Amount;

        [ProtoMember(4)] [DataMember] [Id(3)] public decimal Monetary_Amount2;

        [ProtoMember(5)] [DataMember] [Id(4)] public decimal Monetary_Amount3;

        [ProtoMember(10)] [DataMember] [Id(9)] public string Patient_Status_Code;

        [ProtoMember(13)] [DataMember] [Id(12)] public decimal Percentage_as_Decimal;

        [ProtoMember(12)] [DataMember] [Id(11)] public string Quantity;

        [ProtoMember(7)] [DataMember] [Id(6)] public string Reference_Identification;

        [ProtoMember(14)] [DataMember] [Id(13)] public string Yes_No_Condition_or_Response_Code;

        public CLP_ClaimPaymentInformation() : base("CLP")
        {
        }

        public static CLP_ClaimPaymentInformation Make()
        {
            return new CLP_ClaimPaymentInformation
            {
                Claim_Submitters_Identifier = NaturalTextGenerator.GenerateWord(),
                Claim_Status_Code = NaturalTextGenerator.GenerateWord(),
                Monetary_Amount = ExternalRandomGenerator.Instance.AsDecimal(),
                Monetary_Amount2 = ExternalRandomGenerator.Instance.AsDecimal(),
                Monetary_Amount3 = ExternalRandomGenerator.Instance.AsDecimal(),
                Claim_Filing_Indicator_Code = NaturalTextGenerator.GenerateWord(),
                Reference_Identification = NaturalTextGenerator.GenerateWord(),
                Facility_Code_Value = NaturalTextGenerator.GenerateWord(),
                Claim_Frequency_Type_Code = NaturalTextGenerator.GenerateWord(),
                Patient_Status_Code = NaturalTextGenerator.GenerateWord(),
                Diagnosis_Related_Group_DRG_Code = NaturalTextGenerator.GenerateWord(),
                Quantity = ExternalRandomGenerator.Instance.AsInt().ToString(),
                Percentage_as_Decimal = ExternalRandomGenerator.Instance.AsDecimal(),
                Yes_No_Condition_or_Response_Code = NaturalTextGenerator.GenerateWord()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class CAS_Adjustment : Segment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string Claim_Adjustment_Group_Code;

        [ProtoMember(2)] [DataMember] [Id(1)] public ClaimAdjustment ClaimAdjustment;

        [ProtoMember(3)] [DataMember] [Id(2)] public List<ClaimAdjustment> ClaimAdjustments;

        public CAS_Adjustment() : base("CAS")
        {
        }

        public static CAS_Adjustment Make()
        {
            return new CAS_Adjustment
            {
                Claim_Adjustment_Group_Code = "CJ3",
                ClaimAdjustment = ClaimAdjustment.Make(),
                ClaimAdjustments = new List<ClaimAdjustment>
                {
                    ClaimAdjustment.Make(),
                    ClaimAdjustment.Make(),
                    ClaimAdjustment.Make(),
                    ClaimAdjustment.Make(),
                    ClaimAdjustment.Make()
                }
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class ClaimAdjustment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string Claim_Adjustment_Reason_Code;

        [ProtoMember(2)] [DataMember] [Id(1)] public decimal Monetary_Amount;

        [ProtoMember(3)] [DataMember] [Id(2)] public decimal? Quantity;

        public static ClaimAdjustment Make()
        {
            return new ClaimAdjustment
            {
                Claim_Adjustment_Reason_Code = "CJ",
                Monetary_Amount = ExternalRandomGenerator.Instance.AsDecimal(),
                Quantity = ExternalRandomGenerator.Instance.AsDecimal()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class NM1_SubLoop
    {
        [ProtoMember(3)] [DataMember] [Id(2)] public NM1_PartyName NM1_CorrectedPatient_InsuredName;

        [ProtoMember(6)] [DataMember] [Id(5)] public NM1_PartyName NM1_CorrectedPriorityPayerName;

        [ProtoMember(5)] [DataMember] [Id(4)] public NM1_PartyName NM1_CrossoverCarrierName;

        [ProtoMember(2)] [DataMember] [Id(1)] public NM1_PartyName NM1_InsuredName;

        [ProtoMember(7)] [DataMember] [Id(6)] public NM1_PartyName NM1_OtherSubscriberName;

        [ProtoMember(1)] [DataMember] [Id(0)] public NM1_PartyName NM1_PatientName;

        [ProtoMember(4)] [DataMember] [Id(3)] public NM1_PartyName NM1_ServiceProviderName;

        public static NM1_SubLoop Make()
        {
            return new NM1_SubLoop
            {
                NM1_PatientName = NM1_PartyName.Make(),
                NM1_InsuredName = NM1_PartyName.Make(),
                NM1_CorrectedPatient_InsuredName = NM1_PartyName.Make(),
                NM1_ServiceProviderName = NM1_PartyName.Make(),
                NM1_CrossoverCarrierName = NM1_PartyName.Make(),
                NM1_CorrectedPriorityPayerName = NM1_PartyName.Make(),
                NM1_OtherSubscriberName = NM1_PartyName.Make()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class NM1_PartyName : Segment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string Entity_Identifier_Code;

        [ProtoMember(11)] [DataMember] [Id(10)] public string Entity_Identifier_Code2;

        [ProtoMember(10)] [DataMember] [Id(9)] public string Entity_Relationship_Code;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Entity_Type_Qualifier;

        [ProtoMember(9)] [DataMember] [Id(8)] public string Identification_Code;

        [ProtoMember(8)] [DataMember] [Id(7)] public string Identification_Code_Qualifier;

        [ProtoMember(4)] [DataMember] [Id(3)] public string Name_First;

        [ProtoMember(3)] [DataMember] [Id(2)] public string Name_Last_or_Organization_Name;

        [ProtoMember(12)] [DataMember] [Id(11)] public string Name_Last_or_Organization_Name2;

        [ProtoMember(5)] [DataMember] [Id(4)] public string Name_Middle;

        [ProtoMember(6)] [DataMember] [Id(5)] public string Name_Prefix;

        [ProtoMember(7)] [DataMember] [Id(6)] public string Name_Suffix;

        public NM1_PartyName() : base("NM1")
        {
        }

        public static NM1_PartyName Make()
        {
            return new NM1_PartyName
            {
                Entity_Identifier_Code = "EI",
                Entity_Type_Qualifier = "QQ",
                Name_Last_or_Organization_Name = NaturalTextGenerator.GenerateFullName(),
                Name_First = NaturalTextGenerator.GenerateFirstName(),
                Name_Middle = NaturalTextGenerator.GenerateFirstName(),
                Name_Prefix = "Mrs.",
                Name_Suffix = "Jr",
                Identification_Code_Qualifier = "CQ",
                Identification_Code = NaturalTextGenerator.GenerateWord(),
                Entity_Relationship_Code = NaturalTextGenerator.GenerateWord(),
                Entity_Identifier_Code2 = NaturalTextGenerator.GenerateWord(),
                Name_Last_or_Organization_Name2 = NaturalTextGenerator.GenerateLastName()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class MIA_InpatientAdjudicationInformation : Segment
    {
        [ProtoMember(2)] [DataMember] [Id(1)] public decimal? Monetary_Amount;

        [ProtoMember(4)] [DataMember] [Id(3)] public decimal? Monetary_Amount2;

        [ProtoMember(10)] [DataMember] [Id(9)] public decimal? Monetary_Amount5;

        [ProtoMember(6)] [DataMember] [Id(5)] public List<decimal> Monetary_Amounts3;

        [ProtoMember(8)] [DataMember] [Id(7)] public List<decimal> Monetary_Amounts4;

        [ProtoMember(1)] [DataMember] [Id(0)] public decimal Quantity;

        [ProtoMember(3)] [DataMember] [Id(2)] public decimal? Quantity2;

        [ProtoMember(7)] [DataMember] [Id(6)] public decimal? Quantity3;

        [ProtoMember(5)] [DataMember] [Id(4)] public string Reference_Identification;

        [ProtoMember(9)] [DataMember] [Id(8)] public List<string> Reference_Identifications2;

        public MIA_InpatientAdjudicationInformation() : base("MIA")
        {
        }

        public static MIA_InpatientAdjudicationInformation Make()
        {
            return new MIA_InpatientAdjudicationInformation
            {
                Quantity = ExternalRandomGenerator.Instance.AsDecimal(),
                Monetary_Amount = ExternalRandomGenerator.Instance.AsDecimal(),
                Quantity2 = ExternalRandomGenerator.Instance.AsDecimal(),
                Monetary_Amount2 = ExternalRandomGenerator.Instance.AsDecimal(),
                Reference_Identification = "Ref",
                Monetary_Amounts3 =
                    new List<decimal>
                    {
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal()
                    },
                Quantity3 = ExternalRandomGenerator.Instance.AsDecimal(),
                Monetary_Amounts4 =
                    new List<decimal>
                    {
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal()
                    },
                Reference_Identifications2 = new List<string> {"RF2", "RF4", "RG1"},
                Monetary_Amount5 = ExternalRandomGenerator.Instance.AsDecimal()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class MOA_OutpatientAdjudicationInformation : Segment
    {
        [ProtoMember(2)] [DataMember] [Id(1)] public decimal? Monetary_Amount;

        [ProtoMember(4)] [DataMember] [Id(3)] public List<decimal> Monetary_Amounts;

        [ProtoMember(1)] [DataMember] [Id(0)] public decimal? Percentage_as_Decimal;

        [ProtoMember(3)] [DataMember] [Id(2)] public List<decimal> Reference_Identifications;

        public MOA_OutpatientAdjudicationInformation() : base("MOA")
        {
        }

        public static MOA_OutpatientAdjudicationInformation Make()
        {
            return new MOA_OutpatientAdjudicationInformation
            {
                Percentage_as_Decimal = ExternalRandomGenerator.Instance.AsDecimal(),
                Monetary_Amount = ExternalRandomGenerator.Instance.AsDecimal(),
                Reference_Identifications =
                    new List<decimal>
                    {
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal()
                    },
                Monetary_Amounts =
                    new List<decimal>
                    {
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal(),
                        ExternalRandomGenerator.Instance.AsDecimal()
                    }
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class DTM_SubLoop
    {
        [ProtoMember(3)] [DataMember] [Id(2)] public DTM_Date DTM_ClaimReceivedDate;

        [ProtoMember(2)] [DataMember] [Id(1)] public DTM_Date DTM_CoverageExpirationDate;

        [ProtoMember(1)] [DataMember] [Id(0)] public List<DTM_Date> DTM_StatementFromorToDates;

        public static DTM_SubLoop Make()
        {
            return new DTM_SubLoop
            {
                DTM_StatementFromorToDates =
                    new List<DTM_Date>
                    {
                        DTM_Date.Make(),
                        DTM_Date.Make(),
                        DTM_Date.Make(),
                        DTM_Date.Make(),
                        DTM_Date.Make()
                    },
                DTM_CoverageExpirationDate = DTM_Date.Make(),
                DTM_ClaimReceivedDate = DTM_Date.Make()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class PER_ClaimContactInformation : Segment
    {
        [ProtoMember(3)] [DataMember] [Id(2)] public string Communication_Number_Qualifier;

        [ProtoMember(4)] [DataMember] [Id(3)] public List<string> Communication_Numbers;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Contact_Function_Code;

        [ProtoMember(5)] [DataMember] [Id(4)] public string Contact_Inquiry_Reference;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Name;

        public PER_ClaimContactInformation() : base("PER")
        {
        }

        public static PER_ClaimContactInformation Make()
        {
            return new PER_ClaimContactInformation
            {
                Contact_Function_Code = "CFC",
                Name = NaturalTextGenerator.GenerateFullName(),
                Communication_Number_Qualifier = "DL",
                Communication_Numbers =
                    new List<string>
                    {
                        NaturalTextGenerator.GenerateEMail(),
                        NaturalTextGenerator.GenerateEMail(),
                        NaturalTextGenerator.GenerateEMail()
                    },
                Contact_Inquiry_Reference = NaturalTextGenerator.GenerateWord()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class AMT_ClaimSupplementalInformation : Segment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string Amount_Qualifier_Code;

        [ProtoMember(3)] [DataMember] [Id(2)] public string Credit_Debit_Flag_Code;

        [ProtoMember(2)] [DataMember] [Id(1)] public decimal Monetary_Amount;

        public AMT_ClaimSupplementalInformation() : base("AMT")
        {
        }

        public static AMT_ClaimSupplementalInformation Make()
        {
            return new AMT_ClaimSupplementalInformation
            {
                Amount_Qualifier_Code = "QC",
                Monetary_Amount = ExternalRandomGenerator.Instance.AsDecimal(),
                Credit_Debit_Flag_Code = "USD"
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class QTY_ClaimSupplementalInformationQuantity : Segment
    {
        [ProtoMember(3)] [DataMember] [Id(2)] public string Description;

        [ProtoMember(4)] [DataMember] [Id(3)] public string Free_form_Information;

        [ProtoMember(2)] [DataMember] [Id(1)] public decimal Quantity;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Quantity_Qualifier;

        public QTY_ClaimSupplementalInformationQuantity() : base("QTY")
        {
        }

        public static QTY_ClaimSupplementalInformationQuantity Make()
        {
            return new QTY_ClaimSupplementalInformationQuantity
            {
                Quantity_Qualifier = "QQ",
                Quantity = ExternalRandomGenerator.Instance.AsDecimal(),
                Description = NaturalTextGenerator.Generate(),
                Free_form_Information = NaturalTextGenerator.Generate()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class TS835_2110_Loop
    {
        [ProtoMember(5)] [DataMember] [Id(4)] public List<AMT_ServiceSupplementalAmount> AMT_ServiceSupplementalAmounts;

        [ProtoMember(3)] [DataMember] [Id(2)] public List<CAS_Adjustment> CAS_ServiceAdjustments;

        [ProtoMember(2)] [DataMember] [Id(1)] public List<DTM_Date> DTM_ServiceDates;

        [ProtoMember(7)] [DataMember] [Id(6)] public List<LQ_HealthCareRemarkCode> LQ_HealthCareRemarkCodes;

        [ProtoMember(6)] [DataMember] [Id(5)] public List<QTY_ServiceSupplementalQuantity>
            QTY_ServiceSupplementalQuantities;

        [ProtoMember(4)] [DataMember] [Id(3)] public REF_SubLoop REF_SubLoop_3;

        [ProtoMember(1)] [DataMember] [Id(0)] public SVC_ServicePaymentInformation SVC_ServicePaymentInformation;

        public static TS835_2110_Loop Make()
        {
            return new TS835_2110_Loop
            {
                SVC_ServicePaymentInformation = SVC_ServicePaymentInformation.Make(),
                DTM_ServiceDates = new List<DTM_Date> {DTM_Date.Make(), DTM_Date.Make(), DTM_Date.Make()},
                CAS_ServiceAdjustments =
                    new List<CAS_Adjustment>
                    {
                        CAS_Adjustment.Make(),
                        CAS_Adjustment.Make(),
                        CAS_Adjustment.Make(),
                        CAS_Adjustment.Make()
                    },
                REF_SubLoop_3 = REF_SubLoop.Make(),
                AMT_ServiceSupplementalAmounts = new List<AMT_ServiceSupplementalAmount>
                {
                    AMT_ServiceSupplementalAmount.Make(),
                    AMT_ServiceSupplementalAmount.Make(),
                    AMT_ServiceSupplementalAmount.Make()
                },
                QTY_ServiceSupplementalQuantities = new List<QTY_ServiceSupplementalQuantity>
                {
                    QTY_ServiceSupplementalQuantity.Make(),
                    QTY_ServiceSupplementalQuantity.Make(),
                    QTY_ServiceSupplementalQuantity.Make()
                },
                LQ_HealthCareRemarkCodes = new List<LQ_HealthCareRemarkCode>
                {
                    LQ_HealthCareRemarkCode.Make(),
                    LQ_HealthCareRemarkCode.Make(),
                    LQ_HealthCareRemarkCode.Make(),
                    LQ_HealthCareRemarkCode.Make()
                }
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class SVC_ServicePaymentInformation : Segment
    {
        [ProtoMember(6)] [DataMember] [Id(5)] public string Description;

        [ProtoMember(2)] [DataMember] [Id(1)] public decimal Monetary_Amount;

        [ProtoMember(3)] [DataMember] [Id(2)] public decimal Monetary_Amount2;

        [ProtoMember(4)] [DataMember] [Id(3)] public string Product_Service_ID;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Qualifier;

        [ProtoMember(5)] [DataMember] [Id(4)] public decimal? Quantity;

        [ProtoMember(7)] [DataMember] [Id(6)] public decimal? Quantity2;

        public SVC_ServicePaymentInformation() : base("SVC")
        {
        }

        public static SVC_ServicePaymentInformation Make()
        {
            return new SVC_ServicePaymentInformation
            {
                Qualifier = "SC",
                Monetary_Amount = ExternalRandomGenerator.Instance.AsDecimal(),
                Monetary_Amount2 = ExternalRandomGenerator.Instance.AsDecimal(),
                Product_Service_ID = NaturalTextGenerator.GenerateWord(),
                Quantity = ExternalRandomGenerator.Instance.AsDecimal(),
                Description = NaturalTextGenerator.Generate(),
                Quantity2 = ExternalRandomGenerator.Instance.AsDecimal()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class AMT_ServiceSupplementalAmount : Segment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string Amount_Qualifier_Code;

        [ProtoMember(3)] [DataMember] [Id(2)] public string Credit_Debit_Flag_Code;

        [ProtoMember(2)] [DataMember] [Id(1)] public decimal Monetary_Amount;

        public AMT_ServiceSupplementalAmount() : base("AMT")
        {
        }

        public static AMT_ServiceSupplementalAmount Make()
        {
            return new AMT_ServiceSupplementalAmount
            {
                Amount_Qualifier_Code = "SD",
                Monetary_Amount = ExternalRandomGenerator.Instance.AsDecimal(),
                Credit_Debit_Flag_Code = NaturalTextGenerator.GenerateWord()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class QTY_ServiceSupplementalQuantity : Segment
    {
        [ProtoMember(4)] [DataMember] [Id(3)] public string Description;

        [ProtoMember(3)] [DataMember] [Id(2)] public string Info;

        [ProtoMember(2)] [DataMember] [Id(1)] public decimal Quantity;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Quantity_Qualifier;

        public QTY_ServiceSupplementalQuantity() : base("QTY")
        {
        }

        public static QTY_ServiceSupplementalQuantity Make()
        {
            return new QTY_ServiceSupplementalQuantity
            {
                Quantity_Qualifier = "DG",
                Quantity = ExternalRandomGenerator.Instance.AsInt(),
                Info = NaturalTextGenerator.Generate(15),
                Description = NaturalTextGenerator.Generate(35)
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class LQ_HealthCareRemarkCode : Segment
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string Code_List_Qualifier_Code;

        [ProtoMember(2)] [DataMember] [Id(1)] public string Industry_Code;

        public LQ_HealthCareRemarkCode() : base("LQ")
        {
        }

        public static LQ_HealthCareRemarkCode Make()
        {
            return new LQ_HealthCareRemarkCode
            {
                Code_List_Qualifier_Code = "QK",
                Industry_Code = NaturalTextGenerator.GenerateWord()
            };
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class PLB_ProviderAdjustment : Segment
    {
        [ProtoMember(2)] [DataMember] [Id(1)] public string Date;

        [ProtoMember(3)] [DataMember] [Id(2)] public MonetaryAmountAdjustment MonetaryAmountAdjustment;

        [ProtoMember(4)] [DataMember] [Id(3)] public List<MonetaryAmountAdjustment> MonetaryAmountAdjustments;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Reference_Identification;

        public PLB_ProviderAdjustment() : base("PLB")
        {
        }

        public static PLB_ProviderAdjustment Make()
        {
            var count = ExternalRandomGenerator.Instance.NextScaledRandomInteger(2, 10);
            var temp = new PLB_ProviderAdjustment
            {
                Reference_Identification = NaturalTextGenerator.GenerateWord(),
                Date = DateTime.Now.ToShortDateString(),
                MonetaryAmountAdjustment = MonetaryAmountAdjustment.Make(),
                MonetaryAmountAdjustments = new List<MonetaryAmountAdjustment>()
            };
            for (var i = 0; i < count; i++)
                temp.MonetaryAmountAdjustments.Add(MonetaryAmountAdjustment.Make());
            return temp;
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public class MonetaryAmountAdjustment
    {
        [ProtoMember(2)] [DataMember] [Id(1)] public decimal MonetaryAmount;

        [ProtoMember(1)] [DataMember] [Id(0)] public string Qualifier;

        public static MonetaryAmountAdjustment Make()
        {
            return new MonetaryAmountAdjustment
            {
                Qualifier = "QA",
                MonetaryAmount = ExternalRandomGenerator.Instance.AsDecimal()
            };
        }
    }
}