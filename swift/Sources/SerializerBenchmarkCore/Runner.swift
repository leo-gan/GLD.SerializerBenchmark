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
    let strategy = Schedule.resolveStrategy()
    let recordRO = Schedule.resolveRecordRunOrder()
    var runOrder = 0
    print("[PROGRESS] Swift Data Model v2: \(sers.count) serializers, \(work.count) cells, \(opts.repetitions) reps, modes=\(modes) schedule=\(strategy) record_run_order=\(recordRO)")

    var errors: [BenchRunError] = []

    for fx in work {
        print("[PROGRESS] Testing Data: \(fx.name) (N=\(fx.instanceCount))")

        // Untimed prepare once per cell.
        var ready: [any BenchSerializer] = []
        var failed = Set<String>()
        var byName: [String: any BenchSerializer] = [:]
        for ser in sers {
            if !ser.supports(testDataName: fx.name) { continue }
            do {
                try ser.prepare(fx)
                ready.append(ser)
                byName[ser.name] = ser
            } catch {
                let msg = String(describing: error)
                FileHandle.standardError.write(Data("[ERROR] prepare \(ser.name) / \(fx.name): \(msg)\n".utf8))
                errors.append(BenchRunError(
                    testDataName: fx.name, serializerName: ser.name,
                    stringOrStream: "prepare", repetition: 0, errorText: msg
                ))
                failed.insert(ser.name)
            }
        }

        func measureAndWrite(ser: any BenchSerializer, mode: String, rep: UInt32, pos: Int) {
            do {
                let serNs: UInt64
                let deserNs: UInt64
                let size: Int
                let out: Any
                if mode == "stream" {
                    let t0 = nowNs()
                    let (buf, n) = try ser.serializeStream(fx)
                    let t1 = nowNs()
                    withExtendedLifetime(buf) {}
                    let decoded = try ser.deserializeStream(buf)
                    let t2 = nowNs()
                    withExtendedLifetime(decoded) {}
                    serNs = t1 &- t0
                    deserNs = t2 &- t1
                    size = n
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
                var ro = -1
                var sp = -1
                if recordRO {
                    ro = runOrder
                    sp = pos
                    runOrder += 1
                }
                logger.writeRow(
                    mode: mode,
                    testDataName: fx.name,
                    repetitions: opts.repetitions,
                    repetitionIndex: rep,
                    serializerName: ser.name,
                    serializerVersion: ser.version,
                    timeSer: serNs,
                    timeDeser: deserNs,
                    size: size,
                    fidelity: 1.0,
                    nativeKind: ser.nativeKind.rawValue,
                    streamMode: ser.streamMode.rawValue,
                    instanceCount: fx.instanceCount,
                    typeConfigHash: fx.typeConfigHash,
                    runOrder: ro,
                    schedulePosition: sp
                )
            } catch {
                let msg = String(describing: error)
                FileHandle.standardError.write(
                    Data("[ERROR] \(ser.name) / \(fx.name) / \(mode): \(msg)\n".utf8)
                )
                errors.append(BenchRunError(
                    testDataName: fx.name, serializerName: ser.name,
                    stringOrStream: mode, repetition: rep, errorText: msg
                ))
                failed.insert(ser.name)
            }
        }

        if strategy == "none" {
            // Legacy: serializer → mode → all reps
            for ser in ready {
                if failed.contains(ser.name) { continue }
                for mode in modes {
                    for i in 0..<opts.repetitions {
                        if failed.contains(ser.name) { break }
                        measureAndWrite(ser: ser, mode: mode, rep: i, pos: 0)
                    }
                }
            }
        } else {
            // block_shuffle: mode → rep → shuffled serializers
            for mode in modes {
                for i in 0..<opts.repetitions {
                    let pool = ready.map(\.name).filter { !failed.contains($0) }
                    let order = Schedule.shuffleSerializerNames(
                        pool,
                        baseSeed: seed,
                        typeId: fx.name,
                        instanceCount: fx.instanceCount,
                        typeConfigHash: fx.typeConfigHash,
                        mode: mode,
                        rep: i
                    )
                    for (pos, nm) in order.enumerated() {
                        if failed.contains(nm) { continue }
                        guard let ser = byName[nm] else { continue }
                        measureAndWrite(ser: ser, mode: mode, rep: i, pos: pos)
                    }
                }
            }
        }
    }

    saveErrors(path: errPath, errors: errors)
    print("[PROGRESS] Complete. Results: \(logPath.path)")
}
