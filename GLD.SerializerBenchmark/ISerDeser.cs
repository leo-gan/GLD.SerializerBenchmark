namespace GLD.SerializerBenchmark
{
    internal interface ISerDeser
    {
        string Serialize(object person);
        T Deserialize<T>(string serialized);
    }
}