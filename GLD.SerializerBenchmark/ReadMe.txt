What is the best serializer in .NET?
No, no, no, this project is not about the best serializer. Here I gather the code which shows in several lines of code, how to use different .NET serializers. Just copy-past code in your project. That is the goal. I want to use serializer in the simplest way but it good to know if this way would really hit your code performance. That is why I added some me measurements, as the byproduct.
Please, do not take measurements too seriously. I have some numbers, but this project is not the right place to get decisions about serializer performance. I did not spent time to get the best results. If you have the expertise, please, feel free to modify code to get numbers that are more reliable.
Installation
Most of serializers installed with NuGet package. Look to the “packages.config” file to get a name of the package. I have included comments in the code about it.
Tests
The test data created by Randomizer. It fills in fields of the Person object with randomly generated data. This object used for one test cycle with all serializers then it is regenerated for the next cycle.
The measured time is for the combined serialization and deserialization operations of the same object. When serializer called the first time, it runs the longest time. This longest time span is also important and it is measured.
For the average time calculation, the 5% slowest and 5 % fastest results ignored. 
Some serializers serialize to strings, others – just to the byte array. I used base64 format to convert byte arrays to strings. I know, it is not fair, because we mostly use a byte array after serialization, not a string. UTF-8 also could be more compact format.
Test Results
Again, do not take test results too seriously. I have some numbers, but this project is not the right place to get conclusions about serializer performance.
The test results below are for the one hundred repetitions.
 
The winner is… not the ProtoBuf but NetSerializer by Tomi Valkeinen. Jil also shows good speed.
Notes:
•	The classic JsonNet serializer used in two JsonNet and JsonNetStream tests. Tests show the difference between using the streams and the serializer helper classes. Helper classes could seriously decrease performance. Therefore, streams are the good way to keep up to the fast speed without too much hassle. 
•	The first call to serializer initializes the serializer that is why it might take thousand times faster to the next calls.
•	For Avro I did not find a fast serializable method but its serialized string size is good. 
•	Json and Binary formats bring not too much difference in the serialized string size.
•	 Many serializers do not work well with Json DateTime format out-of-box. 
•	The new Microsoft Bond serializer does not play well in this project. This puzzle is in my list 
•	The core .NET serializers from Microsoft: XmlSerializer, BinarySerializer, DataContractSerializer are not bad. They show good speed but they not so good for the serialized string size.
•	Test run outputs the errors and the test results on the console. It also traces the serialized strings and the individual test times, which can be seen in DebugView for example. 
