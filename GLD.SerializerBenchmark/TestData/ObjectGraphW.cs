using System;
using System.Collections.Generic;
using System.Linq;
using NFX;
using NFX.Parsing;

namespace GLD.SerializerBenchmark.TestDataW
{
    public class ObjectGraphW
    {
        public  List<Conference> Data = new List<Conference>();
        public  int ConferenceCount;
        public  int EventCount;
        public  int ParticipantCount;

        public static ObjectGraphW Generate(int conferenceCount, int participantCount, int eventCount)
        {
            ObjectGraphW og = new ObjectGraphW();
             og.ConferenceCount = (conferenceCount < 1) ? 1 : conferenceCount ;
             og.ParticipantCount = (participantCount < 1) ? 1 : participantCount ;
             og.EventCount = (eventCount < 1) ? 1 : eventCount ;

            for (var i = 0; i < conferenceCount; i++)
                og.Data.Add(ConferenceBuilder.Build(participantCount, eventCount));

            return og;
        }
    }

    public struct HumanName
    {
        public string FirstName;
        public string MiddleName;
        public string LastName;

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

    public class Address
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

    public struct Relationship
    {
        public Participant Other;
        public string RelationshipName;
    }

    public class Participant
    {
        public Address Billing;
        public Guid ID;
        public HumanName LegalName;
        public DateTime RegistrationDate;
        public HumanName RegistrationName;
        public List<Relationship> Relationships;

        public bool? Reserved_BoolFlag1;
        public bool? Reserved_BoolFlag2;
        public double? Reserved_DblFlag1;
        public double? Reserved_DblFlag2;
        public int? Reserved_IntFlag1;
        public int? Reserved_IntFlag2;
        public Address Residence;
        public Address Shipping;

        public byte[] SpeakerAccessCode;
        public byte[] StageAccessCode;


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


    public class ConferenceTopic
    {
        public int[] AttendanceHistory;
        public string Description;
        public Guid ID;
        public bool? IsBiology;
        public bool? IsMathematics;
        public bool? IsPhysics;
        public string Name;
        public int? PlannedAttendance;
    }

    public class Event
    {
        public DateTime EndTime;
        public Guid ID;
        public List<Participant> Participants;
        public DateTime StartTime;
        public List<ConferenceTopic> Topics;
    }


    public class Conference
    {
        public DateTime? EndDate;
        public List<Event> Events;
        public Guid ID;
        public Address Location;
        public DateTime StartDate;
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
                var evt = new Event
                {
                    ID = Guid.NewGuid(),
                    StartTime = sd,
                    EndTime = sd.AddMinutes(ExternalRandomGenerator.Instance.NextScaledRandomInteger(30, 480)),
                    Participants = new List<Participant>(),
                    Topics = new List<ConferenceTopic>()
                };
                sd = evt.EndTime.AddMinutes(1);
                for (var j = ExternalRandomGenerator.Instance.NextScaledRandomInteger(0, people.Length);
                    j < people.Length;
                    j++)
                    evt.Participants.AddRange(people);

                for (var j = ExternalRandomGenerator.Instance.NextScaledRandomInteger(0, topics.Length);
                    j < topics.Length;
                    j++)
                    evt.Topics.AddRange(topics);

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
}