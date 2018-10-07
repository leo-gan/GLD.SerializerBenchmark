# What is the best serializer in .NET?
First of all, this project is not about the best serializer. The goal of this project is to show in several lines of code, how to use different .NET serializers. Go to the Serializers folder, open the file with name of the serializer you interested, copy-past code for serialization/deserialization in your project. That is the goal. Here is the code to use serializers in the simplest way. The measurements added, but they are just the byproduct.
Please, do not take measurements too seriously. I have some numbers, but this project is not the right place to get decisions about serializer performance. If you think, some serializer does not used in the proper way, please, feel free to modify code.

[Test Result Analysis is here]( https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/GLD.SerializerBenchmark/Analysis.ipynb) 
You can find mode details about [Testing Process]( https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/GLD.SerializerBenchmark/Docs/ResultExplanations.md) and [the Testing Reports]( https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/GLD.SerializerBenchmark/Docs/TestResults.txt)


## Installation
Most of serializers installed with NuGet package. Look to the “packages.config” file to get a name of the package.

## Test Data
The serializer performance depend of the serialized data a lot. A lot! There are several serializers that are good almost with any kind of data, but even they can perform badly on some sort of data.
If you serialize the objects with complex structure, there is a big chance that your serializer crashed or even worth, it can silently skip of serialization/deserialization of some part of the object tree.
You can see it on the test for EDI message, which has a deep hierarchy of the nested objects.

### Serialization Attributes
Some serializers require, that code get the serialization attributes. For example, [Serializable], [DataContract], [ProtoContract], [Schema], etc. attributes.
It could be exactly what you need in some cases. Say, you want to avoid to serialize some parts of the object, so do not add the serialization attributes to these parts.
But sometimes these attributes are not welcome. Look at the EDI class. It has hundreds nested objects, fields. It is a tedious work to add the serialization attributes to all of them. Moreover, sometimes you just don't have an access to the source code of the serialized objects. In this case you have to create the wrapper objects and apply the serialization attributes to these wrappers or do another workaround.
Luckily, some serializers do not require these serialization attributes. I included the **EDI_X12_835_NoAtributes** test data to filter out the serializers that can work without serialization attributes.

### Data Types
Now we have a diversity of the data.
-	Primitive Types:
  - **Integer**
  - **Array of strings**
  - **Telemetry** Data. It is plain object with several fields with primitive types, mostly numbers. **Note:** Many Json serializers cannot properly work with DateTime type!
- **Person** and **SimpleObject** types. They are the typical small objects with shallow nesting. If the serializer cannot work even with such simple data, do not use it!
- **EDI_X12_835** type. It is the EDI message with hundreds nested objects and fields and the deep object nesting. 
- **EDI_X12_835_NoAttributes** type. A copy of the EDI_X12_835 but without the serialization attributes.
- **ObjectGraph** type. A rich object with cyclic references. It is very hard task for serializer and almost none of them can do the work properly.
- **MsgBatching** type. Some serializers can automatically bound several identical objects in a package (the batch) and process it in very efficient way. In some cases, the speed can increase substantially.
