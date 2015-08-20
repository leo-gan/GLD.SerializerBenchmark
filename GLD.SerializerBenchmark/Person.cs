using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using Bond;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using ProtoBuf;
using Serialization;

namespace GLD.SerializerBenchmark
{
    [DataContract]
    [JsonConverter(typeof (StringEnumConverter))]
    [Serializable]
    public enum Gender
    {
        [EnumMember]
        Male,
        [EnumMember]
        Female,
    }

    [SerializableObject(SerializedElements.All, EncodingName = "ASCII")]
    [DataContract]
    [ProtoContract]
    [Schema]
    [Serializable]
    public class Passport
    {
        [DataMember]
        [ProtoMember(1)]
        [Id(0)]
        public string Number { get; set; }

        [DataMember]
        [ProtoMember(2)]
        [Id(1)]
        public string Authority { get; set; }

        [DataMember]
        [ProtoMember(3)]
        [Id(2), global::Bond.Type(typeof(long))]
        public DateTime ExpirationDate { get; set; }
    }

    [SerializableObject(SerializedElements.All, EncodingName = "ASCII")]
    [DataContract]
    [ProtoContract]
    [Schema]
    [Serializable]
    public class PoliceRecord
    {
        [DataMember]
        [ProtoMember(1)]
        [Id(0)]
        public int Id { get; set; }

        [DataMember]
        [ProtoMember(2)]
        [Id(1)]
        public string CrimeCode { get; set; }
    }

    [SerializableObject(SerializedElements.All, EncodingName = "ASCII")]
    [DataContract]
    [ProtoContract]
    [Schema]
    [Serializable]
    public class Person : ITestData
    {
        // private static int maxPoliceRecordCounter = 20;
        public Person()
        {
        }

        public string Name {get { return "Person"; } }

        public  Person Generate()
        {
            return new Person
            {
                FirstName = Randomizer.Name,
                LastName = Randomizer.Name,
                Age = (uint) Randomizer.Rand.Next(120),
                Gender = (Randomizer.Rand.Next(0, 1) == 0) ? Gender.Male : Gender.Female,
                Passport = new Passport
                {
                    Authority = Randomizer.Phrase,
                    ExpirationDate =
                        Randomizer.GetDate(DateTime.UtcNow, DateTime.UtcNow + TimeSpan.FromDays(1000)),
                    Number = Randomizer.Id
                },
                PoliceRecords = Enumerable.Range(0, 20).Select(i => new PoliceRecord
                {
                    Id = i,
                    CrimeCode = Randomizer.Name
                }).ToArray()
            };
        }

        ITestData ITestData.Generate()
        {
            return Generate();
        }

        public List<string> Compare(ITestData comparable)
        {
            return ComparePerson((Person)comparable);
        }

        [DataMember]
        [ProtoMember(1)]
        [Id(0)]
        public string FirstName { get; set; }

        [DataMember]
        [ProtoMember(2)]
        [Id(1)]
        public string LastName { get; set; }

        [DataMember]
        [ProtoMember(3)]
        [Id(2)]
        public uint Age { get; set; }

        [DataMember]
        [ProtoMember(4)]
        [Id(3)]
        public Gender Gender { get; set; }

        [DataMember]
        [ProtoMember(5)]
        [Id(4)]
        public Passport Passport { get; set; }

        [DataMember]
        [ProtoMember(6, OverwriteList = true, IsRequired = false)]
        // OverwriteList happens to be very important in this case, where constructor generates this array!
        // IsRequired is important!
        [Id(5)]
        public PoliceRecord[] PoliceRecords { get; set; }

        //public static void Initialize(int maxPoliceRecords = 20)
        //{
        //    maxPoliceRecordCounter = maxPoliceRecords;
        //}

        public List<string> ComparePerson(Person comparable)
        {
            var errors = new List<string> {"  ************** Comparison failed! "};
            if (comparable == null)
            {
                errors.Add("comparable Person: is null!");
                return errors;
            }

            Compare("FirstName", FirstName, comparable.FirstName, errors);
            Compare("LastName", LastName, comparable.LastName, errors);
            Compare("Age", Age, comparable.Age, errors);
            Compare("Gender", Gender, comparable.Gender, errors);
            Compare("Passport", Passport, comparable.Passport, errors);
            if (Passport != null && comparable.Passport != null)
            {
                Compare("Passport.Authority", Passport.Authority, comparable.Passport.Authority, errors);
                Compare("Passport.ExpirationDate", Passport.ExpirationDate,
                    comparable.Passport.ExpirationDate, errors);
                Compare("Passport.Number", Passport.Number, comparable.Passport.Number, errors);
            }
            Compare("FirstName", FirstName, comparable.FirstName, errors);
            Compare("FirstName", FirstName, comparable.FirstName, errors);
            Compare("FirstName", FirstName, comparable.FirstName, errors);
            Compare("FirstName", FirstName, comparable.FirstName, errors);

            Compare("PoliceRecords", PoliceRecords, comparable.PoliceRecords, errors);
            if (Passport != null && comparable.Passport != null)
            {
                var originalPoliceRecords = PoliceRecords;
                var comparablePoliceRecords = comparable.PoliceRecords;
                Compare("PoliceRecords.Length", originalPoliceRecords.Length,
                    comparablePoliceRecords.Length, errors);

                var minLength = Math.Min(originalPoliceRecords.Length, comparablePoliceRecords.Length);
                for (var i = 0; i < minLength; i++)
                {
                    Compare("PoliceRecords[" + i + "].Id", originalPoliceRecords[i].Id,
                        comparablePoliceRecords[i].Id, errors);
                    Compare("PoliceRecords[" + i + "].CrimeCode", originalPoliceRecords[i].CrimeCode,
                        comparablePoliceRecords[i].CrimeCode, errors);
                }
            }
            return errors;
        }

        private static void Compare(string objectName, object left, object right,
                                    List<string> errors)
        {
            if (!left.Equals(right))
                errors.Add(String.Format("\t{0}: {1} != {2}", objectName, left, right));
        }
    }

    public static class BondTypeAliasConverter
    {
        public static long Convert(DateTime value, long unused)
        {
            return value.ToBinary();
        }

        public static DateTime Convert(long value, DateTime unused)
        {
            return DateTime.FromBinary(value);
        }
    }
}