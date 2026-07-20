import Foundation

public final class CsvLogger {
    private let handle: FileHandle
    private let path: URL

    public init(path: URL) throws {
        self.path = path
        _ = FileManager.default.createFile(atPath: path.path, contents: nil)
        self.handle = try FileHandle(forWritingTo: path)
        let header = "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,NativeKind,StreamMode,DataTypeInstanceCount,TypeConfigHash\n"
        handle.write(Data(header.utf8))
    }

    public func writeRow(
        mode: String,
        testDataName: String,
        repetitions: UInt32,
        repetitionIndex: UInt32,
        serializerName: String,
        serializerVersion: String,
        timeSer: UInt64,
        timeDeser: UInt64,
        size: Int,
        fidelity: Double,
        nativeKind: String,
        streamMode: String,
        instanceCount: Int,
        typeConfigHash: String
    ) {
        let total = timeSer &+ timeDeser
        let opsSer = timeSer > 0 ? 1e9 / Double(timeSer) : 0
        let opsDeser = timeDeser > 0 ? 1e9 / Double(timeDeser) : 0
        let opsTot = total > 0 ? 1e9 / Double(total) : 0
        let line = [
            "swift",
            mode,
            testDataName,
            String(repetitions),
            String(repetitionIndex),
            serializerName,
            serializerVersion,
            String(timeSer),
            String(timeDeser),
            String(size),
            String(total),
            String(format: "%.6f", opsSer),
            String(format: "%.6f", opsDeser),
            String(format: "%.6f", opsTot),
            "0",
            String(format: "%.2f", fidelity),
            nativeKind,
            streamMode,
            String(instanceCount),
            typeConfigHash,
        ].joined(separator: ",") + "\n"
        handle.write(Data(line.utf8))
    }

    public func close() {
        try? handle.close()
    }
}

public struct BenchRunError {
    public var testDataName: String
    public var serializerName: String
    public var stringOrStream: String
    public var repetition: UInt32
    public var errorText: String
}

public func saveErrors(path: URL, errors: [BenchRunError]) {
    if errors.isEmpty {
        try? FileManager.default.removeItem(at: path)
        return
    }
    var text = "TestDataName,SerializerName,StringOrStream,Repetition,ErrorText\n"
    for e in errors {
        let et = e.errorText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: ",", with: ";")
        text += "\(e.testDataName),\(e.serializerName),\(e.stringOrStream),\(e.repetition),\(et)\n"
    }
    try? text.write(to: path, atomically: true, encoding: .utf8)
}
