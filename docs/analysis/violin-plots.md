# Performance Distribution (Violin Plots)

These violin plots visualize the distribution of serialization and deserialization times across different data payloads for both C# and Python serializers. The shape of the "violin" represents the density of measurements: wider sections indicate more measurements at that particular time duration.

## C# Serializers

### Person (Complex Object)
![C# Person](dashboard/violin_csharp_Person.png){ width="50%" }

### Telemetry (Numeric Arrays)
![C# Telemetry](dashboard/violin_csharp_Telemetry.png){ width="50%" }

### EDI 835 (Deeply Nested)
![C# EDI 835](dashboard/violin_csharp_EDI_835.png){ width="50%" }

### String Array
![C# String Array](dashboard/violin_csharp_StringArray.png){ width="50%" }

### Integer (Primitive Baseline)
![C# Integer](dashboard/violin_csharp_Integer.png){ width="50%" }

### Simple Object (Minimal Overhead)
![C# Simple Object](dashboard/violin_csharp_SimpleObject.png){ width="50%" }

### Object Graph (Circular References)
![C# Object Graph](dashboard/violin_csharp_ObjectGraph.png){ width="50%" }

---

## Python Serializers

### Person (Complex Object)
![Python Person](dashboard/violin_python_Person.png){ width="50%" }

### Telemetry (Numeric Arrays)
![Python Telemetry](dashboard/violin_python_Telemetry.png){ width="50%" }

### EDI 835 (Deeply Nested)
![Python EDI 835](dashboard/violin_python_EDI_835.png){ width="50%" }

### String Array
![Python String Array](dashboard/violin_python_StringArray.png){ width="50%" }

### Integer (Primitive Baseline)
![Python Integer](dashboard/violin_python_Integer.png){ width="50%" }

### Simple Object (Minimal Overhead)
![Python Simple Object](dashboard/violin_python_SimpleObject.png){ width="50%" }

### Object Graph (Circular References)
![Python Object Graph](dashboard/violin_python_ObjectGraph.png){ width="50%" }

