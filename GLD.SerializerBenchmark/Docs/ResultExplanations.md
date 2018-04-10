# Test Reports

- All serializers are tested in two modes: **string** and **Stream**.
- Reports sorted by **'Ser+Deser'** column which shows the summary time of the serialization and deserialization steps.
- The speed is measured in the **Ops/sec** [operations in a second].

# Test Execution
- The tests executed in loops in this hierarchy: **DataKinds => sting/Stream => repetitions => Serializers**
- The result of **the first repetition** is not included in the reports. This first repetition usually is much slower due the object initialization.
- The test data (of DataKind type) is initialized before each repetition loop.
- The test data generated randomly but we are trying to generate it with similarity to the real data.

# Test Result Discussions
- Despite the popular belief that string serialization is much slower than the stream serialization [in my case it is because of the base64 conversion for strings], the reality is a little bit different. It is heavily depending on the serializer implementation. Just check the test reports.
- If you think that some serializer shows the unfair results, please, check the code for operations of this serializer in the Serializers folder. Any help with improving this code is highly appreciated.
