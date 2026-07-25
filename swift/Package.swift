// swift-tools-version: 5.10
import PackageDescription
import Foundation

/// Prefix for Cap'n Proto / local toolchains (headers + libs). Override with CAPNP_PREFIX.
let homeLocal: String = {
    if let p = ProcessInfo.processInfo.environment["CAPNP_PREFIX"], !p.isEmpty {
        return p
    }
    let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
    if !home.isEmpty {
        return "\(home)/.local"
    }
    return "/usr/local"
}()

/// Prefer an installed libstdc++ tree (Swift's clang often needs explicit isystem on Linux).
let libstdcxxIsystemFlags: [String] = {
    let fm = FileManager.default
    let multiarch = ProcessInfo.processInfo.environment["DEB_HOST_MULTIARCH"]
        ?? "x86_64-linux-gnu"
    for ver in ["14", "13", "12", "11"] {
        let base = "/usr/include/c++/\(ver)"
        let arch = "/usr/include/\(multiarch)/c++/\(ver)"
        if fm.fileExists(atPath: base) {
            var flags = ["-isystem", base]
            if fm.fileExists(atPath: arch) {
                flags += ["-isystem", arch]
            }
            return flags
        }
    }
    return []
}()

let gccLibDir: String = {
    let fm = FileManager.default
    let multiarch = ProcessInfo.processInfo.environment["DEB_HOST_MULTIARCH"]
        ?? "x86_64-linux-gnu"
    for ver in ["14", "13", "12", "11"] {
        let p = "/usr/lib/gcc/\(multiarch)/\(ver)"
        if fm.fileExists(atPath: p) { return p }
    }
    return "/usr/lib/gcc/x86_64-linux-gnu/11"
}()

let package = Package(
    name: "SerializerBenchmark",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "serializer-benchmark-swift", targets: ["SerializerBenchmark"]),
        .library(name: "SerializerBenchmarkCore", targets: ["SerializerBenchmarkCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/orlandos-nl/IkigaJSON.git", from: "2.0.0"),
        .package(url: "https://github.com/nnabeyang/swift-msgpack.git", from: "1.2.0"),
        .package(url: "https://github.com/nnabeyang/swift-cbor.git", from: "0.0.4"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/CoreOffice/XMLCoder.git", from: "0.17.0"),
        .package(url: "https://github.com/mongodb/swift-bson.git", from: "3.1.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
        .package(url: "https://github.com/google/flatbuffers.git", exact: "24.3.25"),
        .package(url: "https://github.com/lynixliu/SwiftAvroCore.git", from: "2.0.0"),
        .package(url: "https://github.com/christophhagen/BinaryCodable", from: "4.0.0"),
        .package(url: "https://github.com/mattt/swift-toml.git", from: "2.0.0"),
        // CryptoKit-compatible SHA-256 on Linux (Apple platforms use system CryptoKit).
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "CapnpBridge",
            path: "Sources/CapnpBridge",
            exclude: ["gen"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("cxx"),
                .unsafeFlags(
                    ["-I\(homeLocal)/include"]
                        + libstdcxxIsystemFlags
                        + ["-std=c++17", "-Wno-unused-parameter"]
                ),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(homeLocal)/lib",
                    "-L\(homeLocal)/lib64",
                    "-L\(gccLibDir)",
                    "-Xlinker", "-rpath", "-Xlinker", "\(homeLocal)/lib",
                    "-Xlinker", "-rpath", "-Xlinker", "\(homeLocal)/lib64",
                    "-lstdc++",
                    "-lcapnp",
                    "-lkj",
                ]),
            ]
        ),
        .target(
            name: "SerializerBenchmarkCore",
            dependencies: [
                "CapnpBridge",
                .product(name: "IkigaJSON", package: "IkigaJSON"),
                .product(name: "SwiftMsgpack", package: "swift-msgpack"),
                .product(name: "SwiftCbor", package: "swift-cbor"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "XMLCoder", package: "XMLCoder"),
                .product(name: "SwiftBSON", package: "swift-bson"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "FlatBuffers", package: "flatbuffers"),
                .product(name: "SwiftAvroCore", package: "SwiftAvroCore"),
                .product(name: "BinaryCodable", package: "BinaryCodable"),
                .product(name: "TOML", package: "swift-toml"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/SerializerBenchmarkCore"
        ),
        .executableTarget(
            name: "SerializerBenchmark",
            dependencies: ["SerializerBenchmarkCore"],
            path: "Sources/SerializerBenchmark"
        ),
        .testTarget(
            name: "SerializerBenchmarkTests",
            dependencies: ["SerializerBenchmarkCore"],
            path: "Tests/SerializerBenchmarkTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
