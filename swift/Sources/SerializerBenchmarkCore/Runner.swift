import Foundation

private func nowNs() -> UInt64 {
    var ts = timespec()
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return UInt64(ts.tv_sec) * 1_000_000_000 &+ UInt64(ts.tv_nsec)
}

/// Untimed domain conversion after timed deserialize (protobuf Message → suite types, etc.).
private func toDomain(_ ser: any BenchSerializer, _ decoded: Any) throws -> Any {
    if let conv = ser as? DomainConverter {
        return try conv.toDomain(decoded)
    }
    return decoded
}

public struct RunOptions {
    public var repetitions: UInt32
    public var serializerFilter: String
    public var dataFilter: String
    public var logDir: URL

    public init(repetitions: UInt32, serializerFilter: String, dataFilter: String, logDir: URL) {
        self.repetitions = repetitions
        self.serializerFilter = serializerFilter
        self.dataFilter = dataFilter
        self.logDir = logDir
    }
}

public func runBenchmark(_ opts: RunOptions) throws {
    try FileManager.default.createDirectory(at: opts.logDir, withIntermediateDirectories: true)

    // Load Package.resolved versions for SerializerVersion column.
    let packageDir = RunConfig.repoRoot().appendingPathComponent("swift")
    PackageVersions.loadResolved(from: packageDir)

    let ts = ProcessInfo.processInfo.environment["BENCHMARK_TS"]
        ?? {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd-HHmmss"
            return f.string(from: Date())
        }()
    if ProcessInfo.processInfo.environment["BENCHMARK_TS"] == nil {
        setenv("BENCHMARK_TS", ts, 1)
    }

    let logPath = opts.logDir.appendingPathComponent("\(ts).csv")
    let errPath = opts.logDir.appendingPathComponent("\(ts).errors.csv")
    let logger = try CsvLogger(path: logPath)
    defer { logger.close() }

    FileHandle.standardError.write(Data("[PROGRESS] Writing results under \(opts.logDir.path)\n".utf8))

    var seed: UInt64 = 42
    if let s = ProcessInfo.processInfo.environment["BENCHMARK_SEED"], let v = UInt64(s) {
        seed = v
    }

    let runCfg = ProcessInfo.processInfo.environment["BENCHMARK_RUN_CONFIG"]
    let resolved = try RunConfig.loadResolved(runConfigPath: runCfg, seed: seed)
    seed = resolved.seed

    let sf = opts.serializerFilter.lowercased()
    let df = opts.dataFilter.lowercased()

    var sers = allSerializers()
    if !sf.isEmpty {
        sers = sers.filter { $0.name.lowercased().contains(sf) }
    }

    var work: [Fixture] = []
    for cell in resolved.cells {
        if !df.isEmpty, !cell.typeId.lowercased().contains(df) { continue }
        let fx = try fixtureFromCell(
            typeId: cell.typeId,
            typeConfig: cell.typeConfig,
            typeConfigHash: cell.typeConfigHash,
            instanceCount: cell.dataTypeInstanceCount,
            seed: seed
        )
        work.append(fx)
    }

    let modes = resolved.ioModes.isEmpty ? ["bytes", "stream"] : resolved.ioModes
    print("[PROGRESS] Swift Data Model v2: \(sers.count) serializers, \(work.count) cells, \(opts.repetitions) reps, modes=\(modes)")

    var errors: [BenchRunError] = []

    for fx in work {
        print("[PROGRESS] Testing Data: \(fx.name) (N=\(fx.instanceCount))")
        for ser in sers {
            if !ser.supports(testDataName: fx.name) { continue }
            do {
                try ser.prepare(fx)
            } catch {
                let msg = String(describing: error)
                FileHandle.standardError.write(Data("[ERROR] prepare \(ser.name) / \(fx.name): \(msg)\n".utf8))
                errors.append(BenchRunError(
                    testDataName: fx.name, serializerName: ser.name,
                    stringOrStream: "prepare", repetition: 0, errorText: msg
                ))
                continue
            }
            for mode in modes {
                for i in 0..<opts.repetitions {
                    do {
                        let serNs: UInt64
                        let deserNs: UInt64
                        let size: Int
                        let out: Any
                        if mode == "stream" {
                            let t0 = nowNs()
                            let (buf, n) = try ser.serializeStream(fx)
                            let t1 = nowNs()
                            // withExtendedLifetime: optimization barrier (issue #59).
                            withExtendedLifetime(buf) {}
                            let decoded = try ser.deserializeStream(buf)
                            let t2 = nowNs()
                            withExtendedLifetime(decoded) {}
                            serNs = t1 &- t0
                            deserNs = t2 &- t1
                            size = n
                            // Domain conversion intentionally outside the timer.
                            out = try toDomain(ser, decoded)
                        } else {
                            let t0 = nowNs()
                            let buf = try ser.serializeBytes(fx)
                            let t1 = nowNs()
                            withExtendedLifetime(buf) {}
                            let decoded = try ser.deserializeBytes(buf)
                            let t2 = nowNs()
                            withExtendedLifetime(decoded) {}
                            serNs = t1 &- t0
                            deserNs = t2 &- t1
                            size = buf.count
                            out = try toDomain(ser, decoded)
                        }
                        if !fx.fidelity(against: out) {
                            throw BenchError.fidelity
                        }
                        logger.writeRow(
                            mode: mode,
                            testDataName: fx.name,
                            repetitions: opts.repetitions,
                            repetitionIndex: i,
                            serializerName: ser.name,
                            serializerVersion: ser.version,
                            timeSer: serNs,
                            timeDeser: deserNs,
                            size: size,
                            fidelity: 1.0,
                            nativeKind: ser.nativeKind.rawValue,
                            streamMode: ser.streamMode.rawValue,
                            instanceCount: fx.instanceCount,
                            typeConfigHash: fx.typeConfigHash
                        )
                    } catch {
                        let msg = String(describing: error)
                        FileHandle.standardError.write(
                            Data("[ERROR] \(ser.name) / \(fx.name) / \(mode): \(msg)\n".utf8)
                        )
                        errors.append(BenchRunError(
                            testDataName: fx.name, serializerName: ser.name,
                            stringOrStream: mode, repetition: i, errorText: msg
                        ))
                        break
                    }
                }
            }
        }
    }

    saveErrors(path: errPath, errors: errors)
    print("[PROGRESS] Complete. Results: \(logPath.path)")
}
