namespace GLD.SerializerBenchmark
{
    internal interface ISerDeser
    {
        string Serialize<T>(object person);
        T Deserialize<T>(string serialized);
    }
}