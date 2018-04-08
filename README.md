Any distributed system requires serializing to transfer data through the wires. The serializers used to be hidden in adapters and proxies, where developers did not deal with the serialization process explicitly. The WCF serialization is an example, when all we need to know is where to place the **[Serializable]** attributes. Contemporary tendencies bring serializers to the surface. In Windows .NET development the explicit serialization probably have started when James Newton-King created the **Json.Net** serializer and  Microsoft officially declared it the recommended serializer for .NET.

**More than 20 .NET serializers tested here.** If the serializer can use several serializing formats (like the Json and th binary formats), I've thested all of them.

There are many kinds of serializers; they produce very compact data and produce it very fast. There are serializers for messaging, for data stores, for marshaling objects. 

What is the best serializer in .NET?

Sorry, this project is not about the best serializer. Here I gather the code which shows in several lines of code, how to use different .NET serializers. Just copy-past code in your project. That is the goal. I want to use serializer in the simplest way but it is good to know if this way would really hit your code performance. That is why I added some measurements, as the byproduct.

Please, do not take these measurements too seriously. I have some numbers, but this project is not the right place to get decisions about serializer performance. It uses serializers just in the simples way. It does not use the specific methods in some serializers to get the better speed or size.

**Note:** I have not tested the serializers that require [IDL](http://en.wikipedia.org/wiki/Interface_description_language) for serialization: [Thrift](https://thrift.apache.org/), [Cap'n Proto](https://github.com/mgravell/capnproto-net), [FlatBuffers](https://github.com/google/flatbuffers), [Simple Binary Encoding](https://github.com/real-logic/simple-binary-encoding). Those sophisticated beasts are not easy in work, they needed for something more special than straightforward serialization for messaging. These serializers are on my Todo list. ProtoBuf for .NET implementation was upgraded to use attributes instead of IDL, kudos to [Marc Gravell](http://blog.marcgravell.com/). 

## Installation ##
Most of serializers installed with NuGet package. Look to the “packages.config” file to get a name of the package. I have included comments in the code about it.

## Tests ##
Different test data kinds are placed in the TestData folder. The results heavily depend on the kind of the test data for all serializers! I've tried to cover the most popular data kinds including the heavy EDI documents. This part is opinionated :) 

The test data created by Generate(). This test data object used for one test cycle with all serializers, then it is regenerated for the next cycle.

If you want to test serializers for different data with some specific structure, size, or primitive types, add your test class.

The Benchmark outputs **the simple reports for immmediate review**. It also outputs the **raw data into the .csv file** for the detailed alalysis. Plus it outputs **the exceptions and the errors** for thorough analyzing. It is necessary because not all serializers can serialize all kinds of data without problems.
The time is measured for the serialization and deserialization operations and for the combined time of the serialization and deserialization. When serializer called the first time, it usually runs the longest time because of the objects initialization. This first time span is excluded from the reports, so it could not disturb the average measurements. Remember, if we need only a single serialization/deserialization operation, this is the most significant value for us. If we repeat serialization/deserialization many times, the most significant values for us are the **Average operations/sec** measurements, which are in the reports.

We usually use serializers in two ways, we serialize **to strings** or into the byte arrays (**the streams**). Both options are tested. I used base64 format to convert byte arrays to strings. I know, it is not fair, because we can use a byte array after serialization, not a string, which is much faster, at last in the theory. The streams also could be the more compact format in some cases.

## Test Results ##
Do not take test results too seriously. I have some numbers, but this project is not the right place to get conclusions about serializer performance. If the serializer has some bells and whistles for getting better performance, it could show much better results. You'd rather add this code and run it on your specific data in your specific workloads. Here all serializers used in the same simplest way and they show just basic performance.

Please, see [the last test results, winners, and some conclusions on my blog](http://geekswithblogs.net/LeonidGaneline/archive/2015/05/06/serializers-in-.net.-v.2.aspx). 


