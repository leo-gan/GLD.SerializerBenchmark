import Foundation

public struct ResolvedCell {
    public let typeId: String
    public let typeConfig: [String: Any]
    public let typeConfigHash: String
    public let dataTypeInstanceCount: Int
}

public struct ResolvedRun {
    public let cells: [ResolvedCell]
    public let seed: UInt64
    public let ioModes: [String]
}

public enum RunConfig {
    public static func repoRoot(from start: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> URL {
        var dir = start.standardizedFileURL
        for _ in 0..<16 {
            let cfg = dir.appendingPathComponent("config/benchmark_config.yaml")
            if FileManager.default.fileExists(atPath: cfg.path) {
                return dir
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return start
    }

    public static func loadResolved(runConfigPath: String?, seed: UInt64) throws -> ResolvedRun {
        let root = repoRoot()
        let path: String
        if let raw = runConfigPath, !raw.isEmpty {
            if raw.hasPrefix("/") {
                path = raw
            } else {
                // Resolve relative to monorepo root (not process cwd).
                let cleaned = raw.replacingOccurrences(of: "^\\./", with: "", options: .regularExpression)
                let candidate = root.appendingPathComponent(cleaned).standardizedFileURL.path
                if FileManager.default.fileExists(atPath: candidate) {
                    path = candidate
                } else {
                    // Also try cwd-relative absolute expansion
                    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                        .appendingPathComponent(raw).standardizedFileURL.path
                    if FileManager.default.fileExists(atPath: cwd) {
                        path = cwd
                    } else {
                        path = candidate
                    }
                }
            }
        } else {
            path = root.appendingPathComponent("config/library/default.yaml").path
        }

        let script = root.appendingPathComponent("scripts/resolve_run_config.py").path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [script, path, "--seed", String(seed)]
        process.currentDirectoryURL = root
        var env = ProcessInfo.processInfo.environment
        let analysis = root.appendingPathComponent("analysis/src").path
        if let existing = env["PYTHONPATH"], !existing.isEmpty {
            env["PYTHONPATH"] = analysis + ":" + existing
        } else {
            env["PYTHONPATH"] = analysis
        }
        process.environment = env
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let err = String(data: errData, encoding: .utf8) ?? ""
            let out = String(data: outData, encoding: .utf8) ?? ""
            throw BenchError.resolveFailed(err.isEmpty ? out : err)
        }
        guard let json = try JSONSerialization.jsonObject(with: outData) as? [String: Any] else {
            throw BenchError.resolveFailed("invalid JSON from resolver")
        }
        let cellsRaw = json["cells"] as? [[String: Any]] ?? []
        var cells: [ResolvedCell] = []
        for c in cellsRaw {
            let typeId = c["type_id"] as? String ?? ""
            let cfg = c["type_config"] as? [String: Any] ?? [:]
            let hash = c["type_config_hash"] as? String ?? ""
            let n: Int
            if let i = c["data_type_instance_count"] as? Int {
                n = i
            } else if let d = c["data_type_instance_count"] as? Double {
                n = Int(d)
            } else {
                n = 1
            }
            cells.append(ResolvedCell(
                typeId: typeId,
                typeConfig: cfg,
                typeConfigHash: hash,
                dataTypeInstanceCount: n
            ))
        }
        var modes = ["bytes", "stream"]
        if let exec = json["execution"] as? [String: Any],
           let m = exec["io_modes"] as? [String], !m.isEmpty {
            modes = m
        }
        var resolvedSeed = seed
        if let s = json["seed"] as? Int {
            resolvedSeed = UInt64(s)
        }
        return ResolvedRun(cells: cells, seed: resolvedSeed, ioModes: modes)
    }
}
