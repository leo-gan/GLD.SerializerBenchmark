Any distributed system requires serializing to transfer data through the wires. The serializers used to be hidden in adapters and proxies, where developers did not deal with the serialization process explicitly. The WCF serialization is an example, when all we need to know is where to place the **[Serializable]** attributes. Contemporary tendencies bring serializers to the surface. In Windows .NET development, it might have started when James Newton-King created the **Json.Net** serializer and even Microsoft officially declared it the recommended serializer for .NET.

There are many kinds of serializers; they produce very compact data very fast. There are serializers for messaging, for data stores, for marshaling objects. 

What is the best serializer in .NET?

No, no, no, this project is not about the best serializer. Here I gather the code which shows in several lines of code, how to use different .NET serializers. Just copy-past code in your project. That is the goal. I want to use serializer in the simplest way but it good to know if this way would really hit your code performance. That is why I added some measurements, as the byproduct.

Please, do not take these measurements too seriously. I have some numbers, but this project is not the right place to get decisions about serializer performance. I did not spent time to get the best results. If you have the expertise, please, feel free to modify code to get numbers that are more reliable.

**Note:** I have not tested the serializers that require [IDL](http://en.wikipedia.org/wiki/Interface_description_language) for serialization: [Thrift](https://thrift.apache.org/), [Cap'n Proto](https://github.com/mgravell/capnproto-net), [FlatBuffers](https://github.com/google/flatbuffers), [Simple Binary Encoding](https://github.com/real-logic/simple-binary-encoding). Those sophisticated beasts are not easy in work, they needed for something more special than straightforward serialization for messaging. These serializers are on my Todo list. ProtoBuf for .NET implementation was upgraded to use attributes instead of IDL, kudos to [Marc Gravell](http://blog.marcgravell.com/). 

## Installation ##
Most of serializers installed with NuGet package. Look to the “packages.config” file to get a name of the package. I have included comments in the code about it.

## Tests ##
The test data created by Randomizer. It fills in fields of the Person object with randomly generated data. This object used for one test cycle with all serializers, then it is regenerated for the next cycle.

If you want to test serializers for different object size or for different primitive types, change the Person object.

The measured time is for the combined serialization and deserialization operations of the same object. When serializer called the first time, it runs the longest time. This longest time span is also important and it is measured. It is the **Max time**. If we need only single serialization/deserialization, this is the most significant value for us. If we repeat serialization / deserialization many times, the most significant values for us are Average time and **Min time**.

For the **Average time** I calculated two values: 
- For the Average **100%** all measured times are used.  
- For the Average **90%** the 10% slowest results ignored. 

Some serializers serialize to strings, others – just to the byte array. I used base64 format to convert byte arrays to strings. I know, it is not fair, because we mostly use a byte array after serialization, not a string. UTF-8 also could be more compact format.

## Test Results ##
Again, do not take test results too seriously. I have some numbers, but this project is not the right place to get conclusions about serializer performance. You'd rather take this code and run it on your specific data in your specific workflows.

Please, see [the last test results, winners, and some conclusions on my blog](http://geekswithblogs.net/LeonidGaneline/archive/2015/05/06/serializers-in-.net.-v.2.aspx). 


