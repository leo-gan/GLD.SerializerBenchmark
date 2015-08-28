using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Serialization;
using Bond;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using ProtoBuf;
using Serialization;

namespace GLD.SerializerBenchmark.TestData
{
    public class PersonDescription : ITestDataDescription
    {
        private readonly Person _data = Person.Generate();

        public string Name
        {
            get { return "Person"; }
        }

        public string Description
        {
            get { return "Nested objects and an array of objects."; }
        }

        public Type DataType
        {
            get { return typeof (Person); }
        }

        public List<Type> SecondaryDataTypes
        {
            get { return new List<Type> {typeof (Gender), typeof (Passport), typeof (PoliceRecord)}; }
        }

        public object Data
        {
            get { return _data; }
        }
    }

    [DataContract]
    [JsonConverter(typeof (StringEnumConverter))]
    [Serializable]
    public enum Gender
    {
        [EnumMember] Male,
        [EnumMember] Female
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
        [Id(2), Type(typeof (long))]
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
    public class Person
    {
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

        public static Person Generate()
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