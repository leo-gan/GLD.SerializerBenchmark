// swift-tools-version: 5.10
import PackageDescription

let homeLocal = "/home/leo/.local"

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
                .unsafeFlags([
                    "-I\(homeLocal)/include",
                    // Swift's clang may select GCC 12 without libstdc++-12-dev; force GCC 11 headers.
                    "-isystem", "/usr/include/c++/11",
                    "-isystem", "/usr/include/x86_64-linux-gnu/c++/11",
                    "-std=c++17",
                    "-Wno-unused-parameter",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L\(homeLocal)/lib",
                    "-L/usr/lib/gcc/x86_64-linux-gnu/11",
                    "-Xlinker", "-rpath", "-Xlinker", "\(homeLocal)/lib",
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
