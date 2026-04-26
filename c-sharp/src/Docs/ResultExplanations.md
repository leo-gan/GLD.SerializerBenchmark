# Understanding the Test Reports

### Project Philosophy

### Measurement Modes
- Each serializer is benchmarked in two distinct modes: **String** and **Stream**.
- **Reports** are primarily sorted by the **'Ser+Deser'** column, reflecting the total time for a complete serialization-deserialization cycle.
- **Speed** is expressed in **Ops/sec** (Operations per second), providing a clear relative performance metric.

---

### Test Execution Workflow
The benchmarking process follows a hierarchical loop structure:
1. **Data Kinds**: Different complex objects (Person, Telemetry, etc.).
2. **Serialization Mode**: String vs. Stream.
3. **Repetitions**: As specified in the command line (e.g., 100 runs).
4. **Serializers**: All registered serializers are tested against the same data instance.

**Important Note on Cold Starts**: The result of the **first repetition** is excluded from the average calculations. This initial run typically is significantly slower due to JIT compilation and static object initialization.

---

### Serialization Attributes
Some serializers require that code gets serialization attributes. For example, `[Serializable]`, `[DataContract]`, `[ProtoContract]`, `[Schema]`, etc.

It could be exactly what you need in some cases. Say, you want to avoid serializing some parts of the object, so do not add the serialization attributes to these parts. But sometimes these attributes are not welcome. Look at the EDI class. It has hundreds of nested objects and fields. It is tedious work to add the serialization attributes to all of them. Moreover, sometimes you just do not have access to the source code of the serialized objects. In this case you have to create wrapper objects and apply the serialization attributes to these wrappers, or do another workaround.

Luckily, some serializers do not require these serialization attributes. The **EDI_X12_835_NoAttributes** test data is included to filter out the serializers that can work without serialization attributes.

---

### Data Types
The serializer performance depends on the serialized data a lot. A lot! There are several serializers that are good almost with any kind of data, but even they can perform badly on some sort of data. If you serialize objects with complex structure, there is a big chance that your serializer crashes or, even worse, it can silently skip serialization/deserialization of some part of the object tree. You can see it on the test for the EDI message, which has a deep hierarchy of nested objects.

- **Primitive Types**:
  - **Integer**
  - **Array of strings**
  - **Telemetry** Data. It is a plain object with several fields with primitive types, mostly numbers. **Note:** Many JSON serializers cannot properly work with DateTime type!
- **Person** and **SimpleObject** types. They are typical small objects with shallow nesting. If the serializer cannot work even with such simple data, do not use it!
- **EDI_X12_835** type. It is the EDI message with hundreds of nested objects and fields and deep object nesting.
- **EDI_X12_835_NoAttributes** type. A copy of the EDI_X12_835 but without the serialization attributes.
- **ObjectGraph** type. A rich object with cyclic references. It is a very hard task for a serializer and almost none of them can do the work properly.
- **MsgBatching** type. Some serializers can automatically bind several identical objects in a package (the batch) and process it in a very efficient way. In some cases, the speed can increase substantially.

---

### Key Discussion Points
- **String vs. Stream**: While there is a common belief that string serialization is slower, our results show this depends heavily on the specific serializer implementation. In this suite, string serialization includes the cost of Base64 conversion where applicable.
- **Fairness & Tuning**: All serializers are used with their default configurations to ensure a "plug-and-play" baseline. If you believe a specific library can perform significantly better with optional tuning, please feel free to contribute an optimized implementation in the `Serializers/` folder.
