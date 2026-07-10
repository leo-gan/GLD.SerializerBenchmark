namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>Tabular row DTOs for CsvHelper (library contracts — not suite domain types).</summary>
    public class CsvFlatRow
    {
        public bool FBool { get; set; }
        public int FInt32 { get; set; }
        public long FInt64 { get; set; }
        public double FFloat64 { get; set; }
        public string FString { get; set; }
        public bool FBool2 { get; set; }
        public int FInt322 { get; set; }
        public string FString2 { get; set; }
    }

    public class CsvEventRow
    {
        public string EventId { get; set; }
        public string EventType { get; set; }
        public long OccurredAt { get; set; }
        public string Producer { get; set; }
        public string Attrs { get; set; }
    }

    public class CsvStringRow
    {
        public string Items { get; set; }
    }
}
