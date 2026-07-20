import Foundation
import SerializerBenchmarkCore

func defaultLogDir() -> URL {
    if let d = ProcessInfo.processInfo.environment["LOG_DIR"] {
        let url = URL(fileURLWithPath: d)
        if url.lastPathComponent == "swift" {
            return url
        }
        return url.appendingPathComponent("swift")
    }
    let root = RunConfig.repoRoot()
    return root.appendingPathComponent("logs/swift")
}

var reps: UInt32 = 10
var serFilter = ""
var dataFilter = ""
var logDir = defaultLogDir()

let args = Array(CommandLine.arguments.dropFirst())
if args.count >= 1, let r = UInt32(args[0]), r > 0 {
    reps = r
}
if args.count >= 2 { serFilter = args[1] }
if args.count >= 3 { dataFilter = args[2] }

// Optional flags: --log-dir=
for a in args {
    if a.hasPrefix("--log-dir=") {
        logDir = URL(fileURLWithPath: String(a.dropFirst("--log-dir=".count)))
    }
}

let opts = RunOptions(
    repetitions: reps,
    serializerFilter: serFilter,
    dataFilter: dataFilter,
    logDir: logDir
)

do {
    try runBenchmark(opts)
} catch {
    fputs("fatal: \(error)\n", stderr)
    exit(1)
}
