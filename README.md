Any distributed system requires serializing to transfer data through the wires. The serializers used to be hidden in adapters and proxies, where developers did not deal with the serialization process explicitly. The WCF serialization is an example, when all we need to know is where to place the **[Serializable]** attributes. Contemporary tendencies bring serializers to the surface. In Windows .NET development, it might have started when James Newton-King created the **Json.Net** serializer and even Microsoft officially declared it the recommended serializer for .NET.

There are many kinds of serializers; they produce very compact data very fast. There are serializers for messaging, for data stores, for marshaling objects. 

What is the best serializer in .NET?

No, no, no, this project is not about the best serializer. Here I gather the code which shows in several lines of code, how to use different .NET serializers. Just copy-past code in your project. That is the goal. I want to use serializer in the simplest way but it good to know if this way would really hit your code performance. That is why I added some measurements, as the byproduct.

Please, do not take these measurements too seriously. I have some numbers, but this project is not the right place to get decisions about serializer performance. I did not spent time to get the best results. If you have the expertise, please, feel free to modify code to get numbers that are more reliable.

**Note:** I have not tested the serializers that require [IDL](http://en.wikipedia.org/wiki/Interface_description_language) for serialization: [Thrift](https://thrift.apache.org/), new [Microsoft Bond](https://github.com/Microsoft/bond), [Cap'n Proto](https://github.com/mgravell/capnproto-net), [FlatBuffers](https://github.com/google/flatbuffers), [Simple Binary Encoding](https://github.com/real-logic/simple-binary-encoding). Those sophisticated beasts are not easy in work, they needed for something more special than straightforward serialization for messaging. These serializers are on my Todo list. ProtoBuf for .NET implementation was upgraded to use attributes instead of IDL, kudos to [Marc Gravell](http://blog.marcgravell.com/). 

## Installation ##
Most of serializers installed with NuGet package. Look to the “packages.config” file to get a name of the package. I have included comments in the code about it.

## Tests ##
The test data created by Randomizer. It fills in fields of the Person object with randomly generated data. This object used for one test cycle with all serializers then it is regenerated for the next cycle.

The measured time is for the combined serialization and deserialization operations of the same object. When serializer called the first time, it runs the longest time. This **longest time** span is also important and it is measured.

For the **average time** calculation, the 5% slowest and 5 % fastest results ignored.

Some serializers serialize to strings, others – just to the byte array. I used base64 format to convert byte arrays to strings. I know, it is not fair, because we mostly use a byte array after serialization, not a string. UTF-8 also could be more compact format.

## Test Results ##
Again, do not take test results too seriously. I have some numbers, but this project is not the right place to get conclusions about serializer performance.

Please, see [the last test results on my blog](http://geekswithblogs.net/LeonidGaneline/archive/2015/02/26/serializers-in-.net.aspx). 



The winner is… not the **ProtoBuf** but [NetSerializer](http://www.codeproject.com/Articles/351538/NetSerializer-A-Fast-Simple-Serializer-for-NET) by Tomi Valkeinen. **Jil** and **MsgPack** also show good speed and compacted strings.

**Notes:**

- The classic **Json.Net** serializer used in two *JsonNet (helper)* and *JsonNet (Stream)* tests. Tests show the difference between using the streams and the serializer **helper classes**. Helper classes could seriously decrease performance. Therefore, streams are the good way to keep up to the fast speed without too much hassle.
- The **first call** to serializer initializes the serializer that is why it might take thousand times faster to the next calls.
- For **Avro** I did not find a fast serializable method but its serialized string size is good. It has some bug, preventing it from passing serialized type to the class (see the comments in code).
- **Json** and **Binary** formats bring not too much difference in the serialized string size.
- Many serializers do not work well with **Json DateTime format** out-of-box. Only **NetSerializer** and **Json.Net** take care of DateTime format.
- The core .NET serializers from Microsoft: **XmlSerializer**, **BinarySerializer**, **DataContractSerializer** are not bad. They show good speed but they not so good for the serialized string size. The **JavaScriptSerializer** produces compact strings but not fast.
- Test run outputs the errors and the test results on the console. It also traces the serialized strings and the individual test times, which can be seen in DebugView for example.
**[Update2015-03-19]** Updated all GitHub packages. NetSerializer in version 3 now. It changed (simplified) some initialization code. It is now even faster.
