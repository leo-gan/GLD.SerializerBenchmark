# Performance (Violin Plots)

Violin plots show the density of serialize / deserialize timings (wider = more samples at that duration). Generated **locally** by `analyze-benchmarks --generate-plots` into `docs/analysis/plots/violin/` for the documentation site (not by GitHub Actions). Re-running benchmarks elsewhere may produce different shapes — that is expected and OK.

Time axis is **microseconds** (normalized from ticks or nanoseconds in the CSVs). Log scale is used when serializer medians span ≥5×.

| Language | Plot for |
|----------|----------|
| C# | ![EDI_835](plots/violin/csharp_EDI_835.png){ width="50%" } |
| C# | ![Integer](plots/violin/csharp_Integer.png){ width="50%" } |
| C# | ![ObjectGraph](plots/violin/csharp_ObjectGraph.png){ width="50%" } |
| C# | ![Person](plots/violin/csharp_Person.png){ width="50%" } |
| C# | ![SimpleObject](plots/violin/csharp_SimpleObject.png){ width="50%" } |
| C# | ![StringArray](plots/violin/csharp_StringArray.png){ width="50%" } |
| C# | ![Telemetry](plots/violin/csharp_Telemetry.png){ width="50%" } |
| Python | ![EDI_835](plots/violin/python_EDI_835.png){ width="50%" } |
| Python | ![Integer](plots/violin/python_Integer.png){ width="50%" } |
| Python | ![ObjectGraph](plots/violin/python_ObjectGraph.png){ width="50%" } |
| Python | ![Person](plots/violin/python_Person.png){ width="50%" } |
| Python | ![SimpleObject](plots/violin/python_SimpleObject.png){ width="50%" } |
| Python | ![StringArray](plots/violin/python_StringArray.png){ width="50%" } |
| Python | ![Telemetry](plots/violin/python_Telemetry.png){ width="50%" } |
| Rust | ![EDI_835](plots/violin/rust_EDI_835.png){ width="50%" } |
| Rust | ![Integer](plots/violin/rust_Integer.png){ width="50%" } |
| Rust | ![Person](plots/violin/rust_Person.png){ width="50%" } |
| Rust | ![SimpleObject](plots/violin/rust_SimpleObject.png){ width="50%" } |
| Rust | ![StringArray](plots/violin/rust_StringArray.png){ width="50%" } |
| Rust | ![Telemetry](plots/violin/rust_Telemetry.png){ width="50%" } |
| C | ![EDI_835](plots/violin/c_EDI_835.png){ width="50%" } |
| C | ![Integer](plots/violin/c_Integer.png){ width="50%" } |
| C | ![Person](plots/violin/c_Person.png){ width="50%" } |
| C | ![SimpleObject](plots/violin/c_SimpleObject.png){ width="50%" } |
| C | ![StringArray](plots/violin/c_StringArray.png){ width="50%" } |
| C | ![Telemetry](plots/violin/c_Telemetry.png){ width="50%" } |
| JavaScript | ![EDI_835](plots/violin/javascript_EDI_835.png){ width="50%" } |
| JavaScript | ![Integer](plots/violin/javascript_Integer.png){ width="50%" } |
| JavaScript | ![Person](plots/violin/javascript_Person.png){ width="50%" } |
| JavaScript | ![SimpleObject](plots/violin/javascript_SimpleObject.png){ width="50%" } |
| JavaScript | ![StringArray](plots/violin/javascript_StringArray.png){ width="50%" } |
| JavaScript | ![Telemetry](plots/violin/javascript_Telemetry.png){ width="50%" } |
