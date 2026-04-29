# Test Data Configuration Design

To ensure consistent benchmarking across different languages (C# and Python), we use a centralized configuration file located at `schemas/test_data_config.json`. This allows us to control the structure and size of the test objects, making comparisons more accurate.

## Configuration Parameters

### StringOptions

- **MinWordLength / MaxWordLength**: Controls the size of individual words generated for names and descriptions.
- **MinPhraseLength / MaxPhraseLength**: Controls the number of words in a phrase (e.g., for authorities or descriptions).
- **MinIdLength / MaxIdLength**: Controls the length of generated ID strings.
- **DuplicationFactor**: A value between 0 and 1 representing the probability that a previously generated string will be reused instead of generating a new one. This is crucial for testing serialization algorithms that support object referencing or string deduplication (e.g., CBOR with sharing, or custom deduplication in some formats).

### CollectionOptions

- **PersonPoliceRecordsCount**: The number of records in the `PoliceRecords` array for the `Person` object.
- **TelemetryMeasurementsCount**: The number of double-precision floating-point numbers in the `TelemetryData` object.
- **StringArrayCount**: The number of strings in the `StringArrayObject`.
- **EdiClaimsCount / EdiLinesPerClaimCount**: Controls the complexity of the EDI 835 document.

### RandomSeed

- A fixed seed to ensure that the "random" data generated is identical across different runs and different languages, provided the PRNG implementation is compatible or we use a similar logic.

## Design Reasons

1. **Reproducibility**: By using a fixed seed and shared configuration, we can guarantee that the same data payload is being serialized in both C# and Python benchmarks.
2. **Real-life Resemblance**: Default values are chosen to reflect typical data sizes in enterprise applications. For example, a telemetry packet often contains around 100 measurements, and a person's record typically doesn't have hundreds of police records.
3. **Serialization Optimization Testing**: The `DuplicationFactor` allows us to stress-test how different serializers handle redundant data. Serializers that use dictionary-based compression or object tracking should show significantly better performance and smaller payloads when this factor is high.
4. **Cross-Language Consistency**: Hardcoding these values in each language's source code was prone to desynchronization. Moving them to a shared schema ensures they are always in sync.
