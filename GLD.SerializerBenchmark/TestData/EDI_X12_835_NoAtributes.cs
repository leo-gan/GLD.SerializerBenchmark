using System;
using System.Collections.Generic;
using NFX;
using NFX.Parsing;

namespace GLD.SerializerBenchmark.TestData.NoAtributes
{
    public class EDI_X12_835Description : ITestDataDescription
    {
        public string Name { get { return "EDI_X12_835"; }}
       public string Description { get{ return "Similar to EDI_X12_835 but internal classes are without additional serialize atributes.."; }}
        public Type DataType { get { return typeof (EDI_X12_835); } }
        public List<Type> SecondaryDataTypes { get { return new List<Type>{}; } }

        private readonly EDI_X12_835 _data = EDI_X12_835.Generate();

        public object Data { get { return _data; }  }
    }

    public abstract class Segment
    {
        public string SegmentTag;

        public Segment(string segmentTag)
        {
            SegmentTag = segmentTag;
        }
    }

    public class EDI_X12_835
    {
        public BPR_FinancialInformation BPR_FinancialInformation;
        public CUR_ForeignCurrencyInformation CUR_ForeignCurrencyInformation;
        public DTM_Date DTM_ProductionDate;
        public N1_SubLoop N1_SubLoop;
        public List<PLB_ProviderAdjustment> PLB_ProviderAdjustmentList;
        public List<REF_SubLoop> REF_SubLoops;
        public TRN_ReassociationTraceNumber TRN_ReassociationTraceNumber;
        public TS835_2000_Loop TS835_2000_Loop;
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

    }
    public class AccoungInfo
    {
        public string Account_Number;
        public string Account_Number_Qualifier;
        public string DFI_Identification_Number;
        public string DFI_Number_Qualifier;

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
    public class BPR_FinancialInformation : Segment
    {
        public AccoungInfo AccoungInfo1;
        public AccoungInfo AccoungInfo2;
        public AccoungInfo AccoungInfo3;
        public int CreditDebit_Flag_Code;
        public string Date;
        public string Originating_Company_Identifier;
        public string Originating_Company_Supplemental_Code;
        public string Payment_Format_Code;
        public decimal Payment_Method_Code;
        public int TransactionHandlingCode;

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
    public class TRN_ReassociationTraceNumber : Segment
    {
        public string Originatin_Company_Identifier;
        public string Reference_Identification;
        public string Reference_Identification2;
        public string Trace_Type_Code;

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
    public class CUR_DateTime
    {
        public string Date;
        public string Qualifier;
        public string Time;

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
    public class CUR_ForeignCurrencyInformation : Segment
    {
        public List<CUR_DateTime> CUR_DateTimes;
        public string Currency_Code;
        public string Currency_Code2;
        public string Currency_Market_Exchange_Code;
        public string Entity_Identifier_Code;
        public string Entity_Identifier_Code2;
        public string Exchange_Rate;

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
    public class REF_SubLoop
    {
        public REF_Identification REF_ReceiverIdentification;
        public REF_Identification REF_VersionIdentification;

        public static REF_SubLoop Make()
        {
            return new REF_SubLoop
            {
                REF_ReceiverIdentification = REF_Identification.Make(),
                REF_VersionIdentification = REF_Identification.Make()
            };
        }
    }
    public class REF_Identification : Segment
    {
        public string Description;
        public string Description2;
        public string Reference_Identification;
        public string Reference_Identification_Qualifier;

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
    public class DTM_Date : Segment
    {
        public string Date;
        public string Date_Time_Period;
        public string Date_Time_Period_Format_Qualifier;
        public string Date_Time_Qualifier;
        public string Time;
        public string Time_Code;

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
    public class N1_SubLoop
    {
        public TS835_1000A_Loop TS835_1000A_Loop;
        public TS835_1000B_Loop TS835_1000B_Loop;

        public static N1_SubLoop Make()
        {
            return new N1_SubLoop
            {
                TS835_1000A_Loop = TS835_1000A_Loop.Make(),
                TS835_1000B_Loop = TS835_1000B_Loop.Make()
            };
        }
    }
    public class TS835_1000A_Loop
    {
        public N1_PartyIdentification N1_PayerIdentification;
        public N3_PartyAddress N3_PayerAddress;
        public N4_PartyCity_State_ZIPCode N4_PayerCity_State_ZIPCode;
        public PER_SubLoop PER_SubLoop;
        public List<REF_AdditionalPartyIdentification> REF_AdditionalPayerIdentification_Loop;

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
    public class TS835_1000B_Loop
    {
        public N1_PartyIdentification N1_PayeeIdentification;
        public N3_PartyAddress N3_PayeeAddress;
        public N4_PartyCity_State_ZIPCode N4_PayeeCity_State_ZIPCode;
        public RDM_RemittanceDeliveryMethod RDM_RemittanceDeliveryMethod;
        public List<REF_AdditionalPartyIdentification> REF_PayeeAdditionalIdentification;

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
    public class N1_PartyIdentification : Segment
    {
        public string Entity_Identifier_Code;
        public string Entity_Identifier_Code2;
        public string Entity_Relationship_Code;
        public string Identification_Code;
        public string Identification_Code_Qualifier;
        public string Name;

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
    public class N3_PartyAddress : Segment
    {
        public string AddressInformation1;
        public string AddressInformation2;

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
    public class N4_PartyCity_State_ZIPCode : Segment
    {
        public string City_Name;
        public string Country_Code;
        public string Country_Subdivision_Code;
        public string Location_Identifier;
        public string Location_Qualifier;
        public string Postal_Code;
        public string State_or_Province_Code;

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
    public class REF_AdditionalPartyIdentification : Segment
    {
        public string Description;
        public string Description2;
        public string Reference_Identification;
        public string Reference_Identification_Qualifier;

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
    public class PER_SubLoop
    {
        public PER_PartyContactInformation PER_PayerBusinessContactInformation;
        public List<PER_PartyContactInformation> PER_PayerTechnicalContactInformation;
        public PER_PartyContactInformation PER_PayerWEBSite;

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
    public class PER_PartyContactInformation : Segment
    {
        public CommunicationNumber CommunicationNumber1;
        public CommunicationNumber CommunicationNumber2;
        public CommunicationNumber CommunicationNumber3;
        public string Contact_Function_Code;
        public string Contact_Inquiry_Reference;
        public string Name;

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
    public class CommunicationNumber
    {
        public string Communication_Number;
        public string Communication_Number_Qualifier;

        public static CommunicationNumber Make()
        {
            return new CommunicationNumber
            {
                Communication_Number_Qualifier = "QW",
                Communication_Number = NaturalTextGenerator.GenerateEMail()
            };
        }
    }
    public class RDM_RemittanceDeliveryMethod : Segment
    {
        public string Communication_Number;
        public string Info1;
        public string Info2;
        public string Name;
        public string Report_Transmission_Code;

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
    public class TS835_2000_Loop
    {
        public List<AMT_ClaimSupplementalInformation> AMT_ClaimSupplementalInformations;
        public DTM_SubLoop DTM_SubLoop;
        public LX_HeaderNumber LX_HeaderNumber;
        public MIA_InpatientAdjudicationInformation MIA_InpatientAdjudicationInformation;
        public MOA_OutpatientAdjudicationInformation MOA_OutpatientAdjudicationInformation;
        public List<PER_ClaimContactInformation> PER_ClaimContactInformations;
        public List<QTY_ClaimSupplementalInformationQuantity> QTY_ClaimSupplementalInformationQuantities;
        public TS2_ProviderSupplementalSummaryInformation TS2_ProviderSupplementalSummaryInformation;
        public TS3_ProviderSummaryInformation TS3_ProviderSummaryInformation;
        public TS835_2100_Loop TS835_2100_Loop;
        public TS835_2110_Loop TS835_2110_Loop;

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
    public class LX_HeaderNumber : Segment
    {
        public string Assigned_Number;

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
    public class TS3_ProviderSummaryInformation : Segment
    {
        public string Date;
        public string Facility_Code_Value;
        public decimal Monetary_Amount;
        public decimal? Monetary_Amount2;
        public List<decimal> MonetaryAmountList;
        public decimal Quantity;
        public decimal? Quantity2;
        public string Reference_Identification;

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
    public class TS2_ProviderSupplementalSummaryInformation : Segment
    {
        public decimal? Monetary_Amount2;
        public decimal? Monetary_Amount3;
        public List<decimal> Monetary_AmountList;
        public decimal Quantity;

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
    public class TS835_2100_Loop
    {
        public CAS_Adjustment CAS_ClaimsAdjustment;
        public CLP_ClaimPaymentInformation CLP_ClaimPaymentInformation;
        public MIA_InpatientAdjudicationInformation MIA_InpatientAdjudicationInformation;
        public NM1_SubLoop NM1_SubLoop;

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
    public class CLP_ClaimPaymentInformation : Segment
    {
        public string Claim_Filing_Indicator_Code;
        public string Claim_Frequency_Type_Code;
        public string Claim_Status_Code;
        public string Claim_Submitters_Identifier;
        public string Diagnosis_Related_Group_DRG_Code;
        public string Facility_Code_Value;
        public decimal Monetary_Amount;
        public decimal Monetary_Amount2;
        public decimal Monetary_Amount3;
        public string Patient_Status_Code;
        public decimal Percentage_as_Decimal;
        public string Quantity;
        public string Reference_Identification;
        public string Yes_No_Condition_or_Response_Code;

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
    public class CAS_Adjustment : Segment
    {
        public string Claim_Adjustment_Group_Code;
        public ClaimAdjustment ClaimAdjustment;
        public List<ClaimAdjustment> ClaimAdjustments;

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
    public class ClaimAdjustment
    {
        public string Claim_Adjustment_Reason_Code;
        public decimal Monetary_Amount;
        public decimal? Quantity;

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
    public class NM1_SubLoop
    {
        public NM1_PartyName NM1_CorrectedPatient_InsuredName;
        public NM1_PartyName NM1_CorrectedPriorityPayerName;
        public NM1_PartyName NM1_CrossoverCarrierName;
        public NM1_PartyName NM1_InsuredName;
        public NM1_PartyName NM1_OtherSubscriberName;
        public NM1_PartyName NM1_PatientName;
        public NM1_PartyName NM1_ServiceProviderName;

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
    public class NM1_PartyName : Segment
    {
        public string Entity_Identifier_Code;
        public string Entity_Identifier_Code2;
        public string Entity_Relationship_Code;
        public string Entity_Type_Qualifier;
        public string Identification_Code;
        public string Identification_Code_Qualifier;
        public string Name_First;
        public string Name_Last_or_Organization_Name;
        public string Name_Last_or_Organization_Name2;
        public string Name_Middle;
        public string Name_Prefix;
        public string Name_Suffix;

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
    public class MIA_InpatientAdjudicationInformation : Segment
    {
        public decimal? Monetary_Amount;
        public decimal? Monetary_Amount2;
        public decimal? Monetary_Amount5;
        public List<decimal> Monetary_Amounts3;
        public List<decimal> Monetary_Amounts4;
        public decimal Quantity;
        public decimal? Quantity2;
        public decimal? Quantity3;
        public string Reference_Identification;
        public List<string> Reference_Identifications2;

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
    public class MOA_OutpatientAdjudicationInformation : Segment
    {
        public decimal? Monetary_Amount;
        public List<decimal> Monetary_Amounts;
        public decimal? Percentage_as_Decimal;
        public List<decimal> Reference_Identifications;

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
    public class DTM_SubLoop
    {
        public DTM_Date DTM_ClaimReceivedDate;
        public DTM_Date DTM_CoverageExpirationDate;
        public List<DTM_Date> DTM_StatementFromorToDates;

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
    public class PER_ClaimContactInformation : Segment
    {
        public string Communication_Number_Qualifier;
        public List<string> Communication_Numbers;
        public string Contact_Function_Code;
        public string Contact_Inquiry_Reference;
        public string Name;

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
    public class AMT_ClaimSupplementalInformation : Segment
    {
        public string Amount_Qualifier_Code;
        public string Credit_Debit_Flag_Code;
        public decimal Monetary_Amount;

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
    public class QTY_ClaimSupplementalInformationQuantity : Segment
    {
        public string Description;
        public string Free_form_Information;
        public decimal Quantity;
        public string Quantity_Qualifier;

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
    public class TS835_2110_Loop
    {
        public List<AMT_ServiceSupplementalAmount> AMT_ServiceSupplementalAmounts;
        public List<CAS_Adjustment> CAS_ServiceAdjustments;
        public List<DTM_Date> DTM_ServiceDates;
        public List<LQ_HealthCareRemarkCode> LQ_HealthCareRemarkCodes;
        public List<QTY_ServiceSupplementalQuantity> QTY_ServiceSupplementalQuantities;
        public REF_SubLoop REF_SubLoop_3;
        public SVC_ServicePaymentInformation SVC_ServicePaymentInformation;

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
    public class SVC_ServicePaymentInformation : Segment
    {
        public string Description;
        public decimal Monetary_Amount;
        public decimal Monetary_Amount2;
        public string Product_Service_ID;
        public string Qualifier;
        public decimal? Quantity;
        public decimal? Quantity2;

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
    public class AMT_ServiceSupplementalAmount : Segment
    {
        public string Amount_Qualifier_Code;
        public string Credit_Debit_Flag_Code;
        public decimal Monetary_Amount;

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
    public class QTY_ServiceSupplementalQuantity : Segment
    {
        public string Description;
        public string Info;
        public decimal Quantity;
        public string Quantity_Qualifier;

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
    public class LQ_HealthCareRemarkCode : Segment
    {
        public string Code_List_Qualifier_Code;
        public string Industry_Code;

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
    public class PLB_ProviderAdjustment : Segment
    {
        public string Date;
        public MonetaryAmountAdjustment MonetaryAmountAdjustment;
        public List<MonetaryAmountAdjustment> MonetaryAmountAdjustments;
        public string Reference_Identification;

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
    public class MonetaryAmountAdjustment
    {
        public decimal MonetaryAmount;
        public string Qualifier;

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