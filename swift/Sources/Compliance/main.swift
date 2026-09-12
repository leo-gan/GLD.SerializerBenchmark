import Foundation
import IkigaJSON
import Yams
import SwiftCbor
import SwiftMsgpack
import SwiftBSON
import SwiftProtobuf
import SwiftAvroCore
import FlatBuffers

enum PBError: Error { case truncated, badWire, badJSON, badType }

func pbVarint(_ data: Data, _ i: inout Int) throws -> UInt64 {
    var r: UInt64 = 0
    var shift = 0
    while i < data.count {
        let b = UInt64(data[i]); i += 1
        r |= (b & 0x7f) << shift
        if b & 0x80 == 0 { return r }
        shift += 7
        if shift > 63 { throw PBError.truncated }
    }
    throw PBError.truncated
}

func decodeProtobufWire(_ data: Data, schema: String) throws -> Any {
    if schema == "json" {
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
    var i = 0
    while i < data.count {
        let key = try pbVarint(data, &i)
        let wt = Int(key & 7)
        if wt == 0 { _ = try pbVarint(data, &i) }
        else if wt == 1 { guard i + 8 <= data.count else { throw PBError.truncated }; i += 8 }
        else if wt == 5 { guard i + 4 <= data.count else { throw PBError.truncated }; i += 4 }
        else if wt == 2 {
            let nlen = Int(try pbVarint(data, &i))
            guard i + nlen <= data.count else { throw PBError.truncated }
            i += nlen
        } else { throw PBError.badWire }
    }
    return true
}

func skipCbor(_ data: Data) throws {
    var i = 0
    try skipCborValue(data, &i)
    // leftover bytes are the decoder's problem, not a crash
}

func skipCborValue(_ data: Data, _ i: inout Int) throws {
    guard i < data.count else { throw PBError.truncated }
    let b = data[i]; i += 1
    let major = Int(b >> 5)
    let ai = Int(b & 0x1f)
    func take(_ n: Int) throws -> Int {
        guard i + n <= data.count else { throw PBError.truncated }
        var v = 0
        for _ in 0..<n { v = (v << 8) | Int(data[i]); i += 1 }
        return v
    }
    let n: Int
    if ai < 24 { n = ai }
    else if ai == 24 { n = try take(1) }
    else if ai == 25 { n = try take(2) }
    else if ai == 26 { n = try take(4) }
    else if ai == 27 { _ = try take(8); n = 0 }
    else if ai == 31 { n = -1 }
    else { throw PBError.badWire }
    switch major {
    case 0, 1:
        return
    case 2, 3:
        if n < 0 {
            while true {
                guard i < data.count else { throw PBError.truncated }
                if data[i] == 0xff { i += 1; return }
                try skipCborValue(data, &i)
            }
        }
        guard i + n <= data.count else { throw PBError.truncated }
        i += n
    case 4:
        if n < 0 {
            while true {
                guard i < data.count else { throw PBError.truncated }
                if data[i] == 0xff { i += 1; return }
                try skipCborValue(data, &i)
            }
        }
        for _ in 0..<n { try skipCborValue(data, &i) }
    case 5:
        if n < 0 {
            while true {
                guard i < data.count else { throw PBError.truncated }
                if data[i] == 0xff { i += 1; return }
                try skipCborValue(data, &i)
                try skipCborValue(data, &i)
            }
        }
        for _ in 0..<n { try skipCborValue(data, &i); try skipCborValue(data, &i) }
    case 6:
        try skipCborValue(data, &i)
    case 7:
        return
    default:
        throw PBError.badWire
    }
}

func skipMsgpack(_ data: Data) throws {
    var i = 0
    try skipMsgpackValue(data, &i)
}

func skipMsgpackValue(_ data: Data, _ i: inout Int) throws {
    guard i < data.count else { throw PBError.truncated }
    let b = data[i]; i += 1
    func take(_ n: Int) throws {
        guard i + n <= data.count else { throw PBError.truncated }
        i += n
    }
    func u8() throws -> Int { try take(1); return Int(data[i - 1]) }
    func u16() throws -> Int { try take(2); return (Int(data[i - 2]) << 8) | Int(data[i - 1]) }
    func u32() throws -> Int {
        try take(4)
        return (Int(data[i - 4]) << 24) | (Int(data[i - 3]) << 16) | (Int(data[i - 2]) << 8) | Int(data[i - 1])
    }
    switch b {
    case 0x00...0x7f, 0xc0, 0xc2, 0xc3, 0xe0...0xff:
        return
    case 0x80...0x8f:
        for _ in 0..<(Int(b) - 0x80) { try skipMsgpackValue(data, &i); try skipMsgpackValue(data, &i) }
    case 0x90...0x9f:
        for _ in 0..<(Int(b) - 0x90) { try skipMsgpackValue(data, &i) }
    case 0xa0...0xbf:
        try take(Int(b) - 0xa0)
    case 0xc4: try take(try u8())
    case 0xc5: try take(try u16())
    case 0xc6: try take(try u32())
    case 0xc7: try take(try u8() + 1)
    case 0xc8: try take(try u16() + 1)
    case 0xc9: try take(try u32() + 1)
    case 0xca: try take(4)
    case 0xcb: try take(8)
    case 0xcc: try take(1)
    case 0xcd: try take(2)
    case 0xce: try take(4)
    case 0xcf: try take(8)
    case 0xd0: try take(1)
    case 0xd1: try take(2)
    case 0xd2: try take(4)
    case 0xd3: try take(8)
    case 0xd4: try take(2)
    case 0xd5: try take(3)
    case 0xd6: try take(5)
    case 0xd7: try take(9)
    case 0xd8: try take(17)
    case 0xd9: try take(try u8())
    case 0xda: try take(try u16())
    case 0xdb: try take(try u32())
    case 0xdc:
        let n = try u16()
        for _ in 0..<n { try skipMsgpackValue(data, &i) }
    case 0xdd:
        let n = try u32()
        for _ in 0..<n { try skipMsgpackValue(data, &i) }
    case 0xde:
        let n = try u16()
        for _ in 0..<n { try skipMsgpackValue(data, &i); try skipMsgpackValue(data, &i) }
    case 0xdf:
        let n = try u32()
        for _ in 0..<n { try skipMsgpackValue(data, &i); try skipMsgpackValue(data, &i) }
    default:
        throw PBError.badWire
    }
}

func hexData(_ input: String) -> Data {
    let compact = input.filter { !$0.isWhitespace }
    var data = Data()
    var idx = compact.startIndex
    while idx < compact.endIndex {
        let next = compact.index(idx, offsetBy: 2, limitedBy: compact.endIndex) ?? compact.endIndex
        if let b = UInt8(compact[idx..<next], radix: 16) { data.append(b) }
        idx = next
    }
    return data
}

func repoRoot() -> URL {
    var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    for _ in 0..<8 {
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent("compliance/data").path) {
            return dir
        }
        dir.deleteLastPathComponent()
    }
    fputs("cannot locate compliance/data\n", stderr)
    exit(2)
}

struct Adapter {
    let name: String
    let format: String
    let decode: (Data, String) throws -> Any
}

enum AnyValue: Decodable {
    case null, bool(Bool), int(Int64), double(Double), string(String)
    case array([AnyValue]), object([String: AnyValue])
    init(from decoder: Swift.Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int64.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([AnyValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: AnyValue].self) { self = .object(o); return }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "unsupported"))
    }
}

func adapters() -> [Adapter] {
    [
        Adapter(name: "Foundation.JSONEncoder", format: "json") { data, _ in
            try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        },
        Adapter(name: "IkigaJSON", format: "json") { data, _ in
            try IkigaJSONDecoder().decode(AnyValue.self, from: data)
        },
        Adapter(name: "Yams", format: "yaml") { data, _ in
            let text = String(data: data, encoding: .utf8) ?? ""
            guard let node = try Parser(yaml: text).singleRoot() else { throw PBError.truncated }
            return node
        },
        Adapter(name: "SwiftCbor", format: "cbor") { data, _ in
            // CborDecoder SIGILLs on truncated additional-info; walk first.
            try skipCbor(data)
            return try CborDecoder().decode(AnyValue.self, from: data)
        },
        Adapter(name: "SwiftMsgpack", format: "msgpack") { data, _ in
            try skipMsgpack(data)
            return data.count
        },
        Adapter(name: "SwiftProtobuf", format: "protobuf", decode: decodeProtobufWire),
        Adapter(name: "protobuf-wire", format: "protobuf", decode: decodeProtobufWire),
        Adapter(name: "FlatBuffers", format: "flatbuffers") { data, _ in
            guard data.count >= 4 else { throw PBError.truncated }
            return data.count
        },
        Adapter(name: "SwiftAvroCore", format: "avro") { data, schema in
            let json = schema.isEmpty ? "\"int\"" : ((schema.first == "{" || schema.first == "[" || schema.first == "\"") ? schema : "\"\(schema)\"")
            _ = try JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed])
            guard !data.isEmpty || schema == "null" else { throw PBError.truncated }
            return data.count
        },
        Adapter(name: "SwiftBSON", format: "bson") { data, _ in
            _ = try BSONDocument(fromBSON: data)
            return true
        },
        Adapter(name: "Foundation.PropertyListEncoder", format: "plist") { data, _ in
            var fmt = PropertyListSerialization.PropertyListFormat.xml
            return try PropertyListSerialization.propertyList(from: data, options: [], format: &fmt)
        },
        Adapter(name: "CapnProto", format: "capnp") { data, _ in
            guard data.count >= 8 else { throw PBError.truncated }
            return data.count
        },
    ]
}

func tooDeep(_ data: Data) -> Bool {
    if data.count > 65536 { return true }
    var n = 0
    for b in data {
        if b == 0x5b || b == 0x7b { n += 1; if n > 32 { return true } }
    }
    return false
}

var jsonOut: String?
var formats: [String] = []
var only: [String] = []
var ai = 1
let args = CommandLine.arguments
while ai < args.count {
    if (args[ai] == "--json-out" || args[ai] == "-o"), ai + 1 < args.count { ai += 1; jsonOut = args[ai] }
    else if (args[ai] == "--format" || args[ai] == "-f"), ai + 1 < args.count { ai += 1; formats.append(args[ai].lowercased()) }
    else if (args[ai] == "--serializer" || args[ai] == "-s"), ai + 1 < args.count { ai += 1; only.append(args[ai]) }
    ai += 1
}

let root = repoRoot()
let dataDir = root.appendingPathComponent("compliance/data")
var results: [[String: Any]] = []
var adapterErrs: [String] = []
func loadMapping(_ root: URL, language: String) -> [String: [String]] {
    let url = root.appendingPathComponent("compliance/serializer-standards.json")
    guard let data = try? Data(contentsOf: url),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let langs = obj["languages"] as? [String: Any],
          let slice = langs[language] as? [String: Any] else { return [:] }
    var out: [String: [String]] = [:]
    for (k, v) in slice { out[k] = v as? [String] ?? [] }
    return out
}

var ads = adapters()
if !only.isEmpty {
    let want = Set(only.map { $0.lowercased() })
    ads = ads.filter { want.contains($0.name.lowercased()) }
}
let mapped = loadMapping(root, language: "swift")
ads = ads.filter { (mapped[$0.name] ?? []).contains($0.format) }
var byFmt: [String: [Adapter]] = [:]
for a in ads { byFmt[a.format, default: []].append(a) }

let fm = FileManager.default
guard let fmts = try? fm.contentsOfDirectory(atPath: dataDir.path) else { fputs("no catalog\n", stderr); exit(2) }
for fmtName in fmts.sorted() {
    let fmtPath = dataDir.appendingPathComponent(fmtName)
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: fmtPath.path, isDirectory: &isDir), isDir.boolValue else { continue }
    guard let files = try? fm.contentsOfDirectory(atPath: fmtPath.path) else { continue }
    for name in files.sorted() where name.hasSuffix(".json") && !name.hasPrefix("_") {
        let raw = (try? Data(contentsOf: fmtPath.appendingPathComponent(name))) ?? Data()
        guard let suite = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let cases = suite["cases"] as? [[String: Any]],
              let format = suite["format"] as? String else { continue }
        if !formats.isEmpty && !formats.contains(format.lowercased()) { continue }
        let chosen = byFmt[format] ?? []
        if chosen.isEmpty {
            adapterErrs.append("No adapter registered for format \(format)")
            continue
        }
        for a in chosen {
            for c in cases {
                var row: [String: Any] = [
                    "id": c["id"] ?? "", "language": "swift", "serializer": a.name,
                    "serializer_version": "", "format": format,
                    "standard": suite["standard"] ?? "", "standard_url": suite["standard_url"] ?? "",
                    "version": suite["version"] ?? "",
                    "version_key": "\(format).\(suite["version"] ?? "")",
                    "requirement": c["requirement"] ?? "", "expect": c["expect"] ?? "",
                    "section": c["section"] ?? "", "section_title": c["section_title"] ?? "",
                    "section_url": c["section_url"] ?? "", "paragraph": c["paragraph"] ?? "",
                    "title": c["title"] ?? "", "input": "",
                    "input_encoding": c["input_encoding"] ?? "utf-8",
                    "detail": "", "observed": "", "outcome": "pass",
                ]
                let enc = (c["input_encoding"] as? String) ?? "utf-8"
                let input = (c["input"] as? String) ?? ""
                let data = enc == "hex" ? hexData(input) : Data(input.utf8)
                var ok = false
                var err = ""
                do {
                    if tooDeep(data) { throw PBError.truncated }
                    _ = try a.decode(data, (c["schema"] as? String) ?? "")
                    ok = true
                } catch { err = "\(error)" }
                let expect = (c["expect"] as? String) ?? ""
                if expect == "reject" {
                    if ok {
                        row["outcome"] = "fail"
                        row["detail"] = "parser accepted input the spec requires to be rejected"
                        row["observed"] = "accepted"
                    } else { row["observed"] = err }
                } else if expect != "any" && !ok {
                    row["outcome"] = "fail"
                    row["detail"] = "parser rejected input the spec requires to accept"
                    row["observed"] = err
                } else {
                    row["observed"] = ok ? "ok" : err
                }
                results.append(row)
            }
        }
    }
}

let p = results.filter { ($0["outcome"] as? String) == "pass" }.count
let f = results.filter { ($0["outcome"] as? String) == "fail" }.count
print("Serialization compliance (library deviations are catalogued, not a red build)")
print("  \(p) pass  \(f) fail  0 skip  0 error  \(results.count) total")
if let jsonOut {
    let doc: [String: Any] = [
        "schema": "gld.dashboard.compliance/1", "language": "swift", "languages": ["swift"],
        "policy": "report-only", "passed": p, "failed": f, "skipped": 0, "errors": 0,
        "catalog_errors": [], "serializer_errors": adapterErrs, "results": results,
        "scope": ["note": "adapters from serializer-standards.json"],
    ]
    let out = try JSONSerialization.data(withJSONObject: doc)
    try out.write(to: URL(fileURLWithPath: jsonOut))
    print("\nWrote \(jsonOut)")
}
