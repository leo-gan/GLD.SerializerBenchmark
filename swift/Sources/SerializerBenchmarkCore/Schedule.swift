#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif
import Foundation

/// B-1 deterministic block_shuffle schedule (must match analysis golden vector).
public enum Schedule {
    public static func normalizeMode(_ mode: String) -> String {
        let m = mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if m == "string" || m == "buffer" { return "bytes" }
        if m == "stream" { return "stream" }
        return m
    }

    public static func deriveScheduleSeed(
        baseSeed: UInt64,
        typeId: String,
        instanceCount: Int,
        typeConfigHash: String,
        mode: String,
        rep: UInt32
    ) -> UInt64 {
        let key = "\(baseSeed)|\(typeId)|\(instanceCount)|\(typeConfigHash)|\(normalizeMode(mode))|\(rep)"
        let digest = SHA256.hash(data: Data(key.utf8))
        var u: UInt64 = 0
        // first 8 bytes little-endian
        let bytes = Array(digest)
        for i in (0..<8).reversed() {
            u = (u << 8) | UInt64(bytes[i])
        }
        return u
    }

    public static func fisherYates<T>(_ items: [T], seed: UInt64) -> [T] {
        var arr = items
        var rng = SplitMix64(state: seed)
        var i = arr.count - 1
        while i > 0 {
            let j = Int(rng.nextU64() % UInt64(i + 1))
            arr.swapAt(i, j)
            i -= 1
        }
        return arr
    }

    public static func shuffleSerializerNames(
        _ names: [String],
        baseSeed: UInt64,
        typeId: String,
        instanceCount: Int,
        typeConfigHash: String,
        mode: String,
        rep: UInt32
    ) -> [String] {
        let seed = deriveScheduleSeed(
            baseSeed: baseSeed,
            typeId: typeId,
            instanceCount: instanceCount,
            typeConfigHash: typeConfigHash,
            mode: mode,
            rep: rep
        )
        return fisherYates(names, seed: seed)
    }

    /// Golden: A,B,C @ seed 42 / message / 1 / abc / bytes / 0 → C,B,A
    public static func goldenPermutation() -> [String] {
        let seed = deriveScheduleSeed(
            baseSeed: 42, typeId: "message", instanceCount: 1,
            typeConfigHash: "abc", mode: "bytes", rep: 0
        )
        return fisherYates(["A", "B", "C"], seed: seed)
    }

    public static func resolveStrategy() -> String {
        let env = (ProcessInfo.processInfo.environment["BENCHMARK_SCHEDULE"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if env == "none" || env == "block_shuffle" { return env }
        return "block_shuffle"
    }

    public static func resolveRecordRunOrder() -> Bool {
        let env = (ProcessInfo.processInfo.environment["BENCHMARK_RECORD_RUN_ORDER"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if env == "0" || env == "false" || env == "no" { return false }
        return true
    }

    private struct SplitMix64 {
        var state: UInt64
        mutating func nextU64() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }
}
