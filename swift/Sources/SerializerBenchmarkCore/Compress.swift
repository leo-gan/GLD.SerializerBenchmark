import Foundation
import GzipC

/// One-shot gzip(6) of already-written bytes. zstd is 0 (no encoder in this target).
public func compressSizes(_ data: Data) -> (gzip: Int, zstd: Int) {
    if data.isEmpty { return (0, 0) }
    let gz = data.withUnsafeBytes { src -> Int in
        guard let p = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
        return Int(bench_gzip_size(p, src.count))
    }
    return (gz, 0)
}
