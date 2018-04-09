# Test Reports

- All serializers are tested in two modes: **string** and **Stream**.
- Reports sorted by **'Ser+Deser'** column which shows the compoundet time of the serialization and deserialization steps.
- The speed is measured in the **Ops/sec** [operations in a second]. 
- The tests executed in loops in this hierarchy: **DataKinds => sting/Stream => Serializers => repetitions**
- The result of **the first repetition** is not included in the reports. This first repetition usually is much slower due the object initialization.
