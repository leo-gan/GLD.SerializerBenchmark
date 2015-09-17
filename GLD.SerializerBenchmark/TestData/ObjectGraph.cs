using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using Bond;
using NFX;
using NFX.Parsing;
using ProtoBuf;

namespace GLD.SerializerBenchmark.TestData
{
    public class ObjectGraphDescription : ITestDataDescription
    {
        public string Name
        {
            get { return "ObjectGraph"; }
        }

        public string Description
        {
            get { return "Object Graph with circular references."; }
        }

        public Type DataType
        {
            get { return typeof (ObjectGraph); }
        }

        public List<Type> SecondaryDataTypes
        {
            get
            {
                return new List<Type>
                {
                    typeof (Address),
                    typeof (Conference),
                    typeof (ConferenceBuilder),
                    typeof (ConferenceTopic),
                    typeof (Event),
                    typeof (HumanName),
                    typeof (Participant),
                    typeof (Relationship)
                };
            }
        }

        public object Data
        {
            get { return ObjectGraph.Generate(3, 3, 3);; }
        }
    }

    [ProtoContract]
    [DataContract]
    [Schema]
    [Serializable]
    public struct HumanName
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string FirstName;
        [ProtoMember(2)] [DataMember] [Id(1)] public string MiddleName;
        [ProtoMember(3)] [DataMember] [Id(2)] public string LastName;

        public static HumanName Build()
        {
            return new HumanName
            {
                FirstName = NaturalTextGenerator.GenerateFirstName(),
                MiddleName =
                    ExternalRandomGenerator.Instance.NextRandomInteger > 500000000
                        ? NaturalTextGenerator.GenerateFirstName()
                        : null,
                LastName = NaturalTextGenerator.GenerateLastName()
            };
        }
    }

    [ProtoContract(AsReferenceDefault = true)]
    [DataContract(IsReference = true)]
    [Schema]
    [Serializable]
    public class Address
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

        public static Address Build()
        {
            var rnd = ExternalRandomGenerator.Instance.NextRandomInteger;
            return new Address
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
    public struct Relationship
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public string RelationshipName;
        [ProtoMember(2, AsReference = true)] [DataMember] [Id(1)] public Participant Other;
    }

    [ProtoContract(AsReferenceDefault = true)]
    [DataContract(IsReference = true)]
    [Serializable]
    public class Participant
    {
        [ProtoMember(7, AsReference = true)] [DataMember] [Id(2)] public Address Billing;
        [ProtoMember(1)] [DataMember] [Id(3)] public Guid ID;
        [ProtoMember(2)] [DataMember] [Id(4)] public HumanName LegalName;
        [ProtoMember(4)] [DataMember] [Id(5)] public DateTime RegistrationDate;
        [ProtoMember(3)] [DataMember] [Id(6)] public HumanName RegistrationName;
        [ProtoMember(8)] [DataMember] [Id(7)] public List<Relationship> Relationships;

        [ProtoMember(9)] [DataMember] [Id(8)] public bool? Reserved_BoolFlag1;
        [ProtoMember(10)] [DataMember] [Id(9)] public bool? Reserved_BoolFlag2;
        [ProtoMember(13)] [DataMember] [Id(10)] public double? Reserved_DblFlag1;
        [ProtoMember(14)] [DataMember] [Id(11)] public double? Reserved_DblFlag2;
        [ProtoMember(11)] [DataMember] [Id(12)] public int? Reserved_IntFlag1;
        [ProtoMember(12)] [DataMember] [Id(13)] public int? Reserved_IntFlag2;
        [ProtoMember(5, AsReference = true)] [DataMember] [Id(14)] public Address Residence;
        [ProtoMember(6, AsReference = true)] [DataMember] [Id(15)] public Address Shipping;
        [ProtoMember(16)] [DataMember] [Id(16)] public byte[] SpeakerAccessCode;

        [ProtoMember(15)] [DataMember] [Id(17)] public byte[] StageAccessCode;


        public static Participant Build()
        {
            var rnd = ExternalRandomGenerator.Instance.NextRandomInteger;
            var primaryAddr = Address.Build();
            return new Participant
            {
                ID = Guid.NewGuid(),
                LegalName = HumanName.Build(),
                RegistrationName = HumanName.Build(),
                RegistrationDate = DateTime.Now.AddDays(-23),
                Residence = primaryAddr,
                Shipping = (0 != (rnd & (1 << 32))) ? primaryAddr : Address.Build(),
                Billing = (0 != (rnd & (1 << 31))) ? primaryAddr : Address.Build(),
                StageAccessCode = (0 != (rnd & (1 << 30))) ? new byte[128] : null,
                SpeakerAccessCode = (0 != (rnd & (1 << 30))) ? new byte[128] : null
            };
        }
    }


    [ProtoContract(AsReferenceDefault = true)]
    [DataContract(IsReference = true)]
    [Schema]
    [Serializable]
    public class ConferenceTopic
    {
        [ProtoMember(8)] [DataMember] [Id(0)] public int[] AttendanceHistory;
        [ProtoMember(3)] [DataMember] [Id(1)] public string Description;
        [ProtoMember(1)] [DataMember] [Id(2)] public Guid ID;
        [ProtoMember(6)] [DataMember] [Id(3)] public bool? IsBiology;
        [ProtoMember(5)] [DataMember] [Id(4)] public bool? IsMathematics;
        [ProtoMember(4)] [DataMember] [Id(5)] public bool? IsPhysics;
        [ProtoMember(2)] [DataMember] [Id(6)] public string Name;
        [ProtoMember(7)] [DataMember] [Id(7)] public int? PlannedAttendance;
    }

    [ProtoContract(AsReferenceDefault = true)]
    [DataContract(IsReference = true)]
    [Schema]
    [Serializable]
    public class Event
    {
        [ProtoMember(3)] [DataMember] [Id(0)] public DateTime EndTime;
        [ProtoMember(1)] [DataMember] [Id(1)] public Guid ID;
        [ProtoMember(5, AsReference = true)] [DataMember] [Id(2)] public List<Participant> Participants;
        [ProtoMember(2)] [DataMember] [Id(3)] public DateTime StartTime;
        [ProtoMember(6, AsReference = true)] [DataMember] [Id(4)] public List<ConferenceTopic> Topics;
    }


    [ProtoContract(AsReferenceDefault = true)]
    [DataContract(IsReference = true)]
    [Schema]
    [Serializable]
    public class Conference
    {
        [ProtoMember(3)] [DataMember] [Id(0)] public DateTime? EndDate;

        [ProtoMember(5, AsReference = true)] [DataMember] [Id(1)] public List<Event> Events;
        [ProtoMember(1)] [DataMember] [Id(2)] public Guid ID;
        [ProtoMember(4, AsReference = true)] [DataMember] [Id(3)] public Address Location;
        [ProtoMember(2)] [DataMember] [Id(4)] public DateTime StartDate;
    }


    public static class ConferenceBuilder
    {
        public static Conference Build(int participantCount, int eventCount)
        {
            var topics = new[]
            {
                new ConferenceTopic
                {
                    ID = Guid.NewGuid(),
                    Name = "Is There a life on Mars?",
                    Description = "We will discuss how aliens eat donuts with honey sitting at a marsian lake shore",
                    PlannedAttendance = 80,
                    IsPhysics = true,
                    AttendanceHistory =
                        new[] {24, 27, 39, 50, 75, 234, 200, 198, 245, 188, 120, 90, 80, 24, 24, 55, 23, 45, 33}
                },
                new ConferenceTopic
                {
                    ID = Guid.NewGuid(),
                    Name = "Solder-Free Welding",
                    Description = "Soldering with sugar syrop",
                    PlannedAttendance = 120,
                    IsBiology = true
                },
                new ConferenceTopic
                {
                    ID = Guid.NewGuid(),
                    Name = "2+2=5",
                    Description = "What do we know about logic?",
                    PlannedAttendance = 4000,
                    IsMathematics = true,
                    AttendanceHistory =
                        new[] {3000, 3245, 2343, 2344, 4332, 23434, 23434, 2343, 545, 2322, 3453, 2332, 2323, 3234}
                },
                new ConferenceTopic
                {
                    ID = Guid.NewGuid(),
                    Name = "Growing Corn",
                    Description = "Corn starches and calories?",
                    PlannedAttendance = 233,
                    IsBiology = true
                }
            };

            var people = new Participant[participantCount];
            for (var i = 0; i < participantCount; i++) people[i] = Participant.Build();

            foreach (var person in people)
            {
                if (ExternalRandomGenerator.Instance.NextRandomInteger < 750000000) continue;
                person.Relationships = new List<Relationship>();
                for (var i = 0; i < ExternalRandomGenerator.Instance.NextScaledRandomInteger(0, 4); i++)
                {
                    var friend = people.FirstOrDefault(p => p != person && p.Relationships == null);
                    person.Relationships.Add(new Relationship {Other = friend, RelationshipName = "Good Friend #" + i});
                }
            }


            var confStartDate = DateTime.Now.AddDays(30);

            var events = new Event[eventCount];
            var sd = confStartDate;
            for (var i = 0; i < eventCount; i++)
            {
                var evt = new Event();
                evt.ID = Guid.NewGuid();
                evt.StartTime = sd;
                evt.EndTime = sd.AddMinutes(ExternalRandomGenerator.Instance.NextScaledRandomInteger(30, 480));
                sd = evt.EndTime.AddMinutes(1);
                evt.Participants = new List<Participant>();
                for (var j = ExternalRandomGenerator.Instance.NextScaledRandomInteger(0, people.Length);
                    j < people.Length;
                    j++)
                    evt.Participants.Add(people[j]);

                evt.Topics = new List<ConferenceTopic>();
                for (var j = ExternalRandomGenerator.Instance.NextScaledRandomInteger(0, topics.Length);
                    j < topics.Length;
                    j++)
                    evt.Topics.Add(topics[j]);

                events[i] = evt;
            }


            var result = new Conference
            {
                ID = Guid.NewGuid(),
                StartDate = confStartDate,
                Location = Address.Build(),
                Events = new List<Event>(events)
            };
            return result;
        }
    }

    [ProtoContract(AsReferenceDefault = true)]
    [DataContract(IsReference = true)]
    [Schema]
    [Serializable]
    public class ObjectGraph
    {
        [ProtoMember(1)] [DataMember] [Id(0)] public int ConferenceCount;
        [ProtoMember(4)] [DataMember] [Id(1)] public List<Conference> Conferences = new List<Conference>();
        [ProtoMember(3)] [DataMember] [Id(2)] public int EventCount;
        [ProtoMember(2)] [DataMember] [Id(3)] public int ParticipantCount;

        public static ObjectGraph Generate(int conferenceCount, int participantCount, int eventCount)
        {
            var objectGraph = new ObjectGraph
            {
                ConferenceCount = conferenceCount < 1 ? 1 : conferenceCount,
                ParticipantCount = participantCount < 1 ? 1 : participantCount,
                EventCount = eventCount < 1 ? 1 : eventCount
            };

            for (var i = 0; i < objectGraph.ConferenceCount; i++)
                objectGraph.Conferences.Add(ConferenceBuilder.Build(objectGraph.ParticipantCount, objectGraph.EventCount));
            return objectGraph;
        }
    }
}