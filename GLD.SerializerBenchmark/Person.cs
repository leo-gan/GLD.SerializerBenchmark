using System;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;

namespace GLD.SerializerBenchmark
{
    [JsonConverter(typeof (StringEnumConverter))]
    [Serializable]
    public enum Gender
    {
        Male,
        Female,
    }

    [Serializable]
    public class Passport
    {
        public string Number { get; set; }
        public string Authority { get; set; }
        public DateTime ExpirationDate { get; set; }
    }

    [Serializable]
    public class PoliceRecord
    {
        public int Id { get; set; }
        public string CrimeCode { get; set; }
    }

    [Serializable]
    public class Person
    {
        private static int maxPoliceRecordCounter = 20;

        public Person()
        {
            FirstName = Randomizer.Name;
            LastName = Randomizer.Name;
            Age = (uint) Randomizer.Rand.Next(120);
            Gender = (Randomizer.Rand.Next(0, 1) == 0) ? Gender.Male : Gender.Female;
            Passport = new Passport
            {
                Authority = Randomizer.Phrase,
                ExpirationDate =
                    Randomizer.GetDate(DateTime.UtcNow, DateTime.UtcNow + TimeSpan.FromDays(1000)),
                Number = Randomizer.Id
            };
            int curPoliceRecordCounter = Randomizer.Rand.Next(20);
            PoliceRecords = new PoliceRecord[curPoliceRecordCounter];
            for (int i = 0; i < curPoliceRecordCounter; i++)
                PoliceRecords[i] = new PoliceRecord
                {
                    Id = int.Parse(Randomizer.Id),
                    CrimeCode = Randomizer.Name
                };
        }

        public string FirstName { get; set; }
        public string LastName { get; set; }
        public uint Age { get; set; }
        public Gender Gender { get; set; }
        public Passport Passport { get; set; }
        public PoliceRecord[] PoliceRecords { get; set; }

        public static void Initialize(int maxPoliceRecords = 20)
        {
            maxPoliceRecordCounter = maxPoliceRecords;
        }

        public List<string> Compare(Person comparable)
        {
            var errors = new List<string> {"************** Comparison failed! "};
            if (comparable == null)
            {
                errors.Add("comparable: is null!");
                return errors;
            }

            Compare("FirstName", FirstName, comparable.FirstName, errors);
            Compare("LastName", LastName, comparable.LastName, errors);
            Compare("Age", Age, comparable.Age, errors);
            Compare("Gender", Gender, comparable.Gender, errors);
            Compare("Passport.Authority", Passport.Authority, comparable.Passport.Authority, errors);
            Compare("Passport.ExpirationDate", Passport.ExpirationDate, comparable.Passport.ExpirationDate, errors);
            Compare("Passport.Number", Passport.Number, comparable.Passport.Number, errors);
            Compare("FirstName", FirstName, comparable.FirstName, errors);
            Compare("FirstName", FirstName, comparable.FirstName, errors);
            Compare("FirstName", FirstName, comparable.FirstName, errors);
            Compare("FirstName", FirstName, comparable.FirstName, errors);

            PoliceRecord[] originalPoliceRecords = PoliceRecords;
            PoliceRecord[] comparablePoliceRecords = comparable.PoliceRecords;
            Compare("PoliceRecords.Length", PoliceRecords.Length, comparable.PoliceRecords.Length, errors);

            for (var i = 0; i < originalPoliceRecords.Length; i++)
            {
                Compare("PoliceRecords[" + i + "].Id", originalPoliceRecords[i].Id, comparablePoliceRecords[i].Id, errors);
                Compare("PoliceRecords[" + i + "].CrimeCode", originalPoliceRecords[i].CrimeCode, comparablePoliceRecords[i].CrimeCode, errors);
            }
            return errors;
        }

        private static void Compare(string objectName, object left, object right, List<string> errors)
        {
            if (!left.Equals(right))
                errors.Add(String.Format("{0}: {1} != {2}", objectName, left, right));
        }
    }
}