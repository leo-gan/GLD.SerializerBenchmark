# Understanding the Test Reports

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

### Key Discussion Points
- **String vs. Stream**: While there is a common belief that string serialization is slower, our results show this depends heavily on the specific serializer implementation. In this suite, string serialization includes the cost of Base64 conversion where applicable.
- **Fairness & Tuning**: All serializers are used with their default configurations to ensure a "plug-and-play" baseline. If you believe a specific library can perform significantly better with optional tuning, please feel free to contribute an optimized implementation in the `Serializers/` folder.
