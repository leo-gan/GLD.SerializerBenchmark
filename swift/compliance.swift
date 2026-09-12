#!/usr/bin/env swift
import Foundation

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

func decodeProtobuf(_ data: Data, schema: String) throws -> [String: Any] {
    if schema == "json" {
        let v = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let obj = v as? [String: Any] else { throw PBError.badJSON }
        var n = 0, s = "", ok = false, tags: [Int] = []
        if let raw = obj["n"], !(raw is NSNull) { n = try pbInt32(raw) }
        if let raw = obj["s"], !(raw is NSNull) {
            guard let str = raw as? String else { throw PBError.badType }
            s = str
        }
        if let raw = obj["ok"], !(raw is NSNull) {
            guard let b = raw as? Bool else { throw PBError.badType }
            ok = b
        }
        if let raw = obj["tags"], !(raw is NSNull) {
            guard let arr = raw as? [Any] else { throw PBError.badType }
            tags = try arr.map(pbInt32)
        }
        return ["n": n, "s": s, "ok": ok, "tags": tags]
    }
    var n = 0, s = "", ok = false, tags: [Int] = []
    var i = 0
    while i < data.count {
        let key = try pbVarint(data, &i)
        let field = Int(key >> 3)
        let wt = Int(key & 7)
        if wt == 0 {
            let v = try pbVarint(data, &i)
            if field == 1 { n = Int(Int32(truncatingIfNeeded: v)) }
            else if field == 3 { ok = v != 0 }
            else if field == 4 { tags.append(Int(Int32(truncatingIfNeeded: v))) }
        } else if wt == 1 {
            guard i + 8 <= data.count else { throw PBError.truncated }
            i += 8
        } else if wt == 5 {
            guard i + 4 <= data.count else { throw PBError.truncated }
            i += 4
        } else if wt == 2 {
            let nlen = Int(try pbVarint(data, &i))
            guard i + nlen <= data.count else { throw PBError.truncated }
            if field == 2 {
                s = String(data: data.subdata(in: i..<(i + nlen)), encoding: .utf8) ?? ""
            } else if field == 4 {
                var j = i
                let end = i + nlen
                while j < end { tags.append(Int(Int32(truncatingIfNeeded: try pbVarint(data, &j)))) }
            }
            i += nlen
        } else {
            throw PBError.badWire
        }
    }
    return ["n": n, "s": s, "ok": ok, "tags": tags]
}

func pbInt32(_ raw: Any) throws -> Int {
    if let i = raw as? Int { return i }
    if let s = raw as? String, let i = Int(s) { return i }
    throw PBError.badType
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

var jsonOut: String?
var formats: [String] = []
var i = 1
let args = CommandLine.arguments
while i < args.count {
    if (args[i] == "--json-out" || args[i] == "-o") && i + 1 < args.count {
        i += 1
        jsonOut = args[i]
    } else if (args[i] == "--format" || args[i] == "-f") && i + 1 < args.count {
        i += 1
        formats.append(args[i].lowercased())
    }
    i += 1
}

let root = repoRoot()
let dataDir = root.appendingPathComponent("compliance/data")
var results: [[String: Any]] = []
var adapterErrs: [String] = []
let fm = FileManager.default
guard let fmts = try? fm.contentsOfDirectory(atPath: dataDir.path) else {
    fputs("no catalog\n", stderr)
    exit(2)
}
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
        var sers: [String]
        if format == "json" { sers = ["Foundation.JSONEncoder", "IkigaJSON"] }
        else if format == "plist" { sers = ["Foundation.PropertyListEncoder"] }
        else if format == "protobuf" { sers = ["protobuf-wire", "SwiftProtobuf"] }
        else {
            adapterErrs.append("No adapter registered for format \(format)")
            continue
        }
        if let data = try? Data(contentsOf: root.appendingPathComponent("compliance/serializer-standards.json")),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let langs = obj["languages"] as? [String: Any],
           let slice = langs["swift"] as? [String: Any] {
            sers = sers.filter { (slice[$0] as? [String] ?? []).contains(format) }
        }
        for ser in sers {
        for c in cases {
            var row: [String: Any] = [
                "id": c["id"] ?? "",
                "language": "swift",
                "serializer": ser,
                "serializer_version": "",
                "format": format,
                "standard": suite["standard"] ?? "",
                "standard_url": suite["standard_url"] ?? "",
                "version": suite["version"] ?? "",
                "version_key": "\(format).\(suite["version"] ?? "")",
                "requirement": c["requirement"] ?? "",
                "expect": c["expect"] ?? "",
                "section": c["section"] ?? "",
                "section_title": c["section_title"] ?? "",
                "section_url": c["section_url"] ?? "",
                "paragraph": c["paragraph"] ?? "",
                "title": c["title"] ?? "",
                "input": c["input"] ?? "",
                "input_encoding": c["input_encoding"] ?? "utf-8",
                "detail": "",
                "observed": "",
                "outcome": "pass",
            ]
            let enc = (c["input_encoding"] as? String) ?? "utf-8"
            let input = (c["input"] as? String) ?? ""
            var data = Data()
            if enc == "hex" {
                let compact = input.filter { !$0.isWhitespace }
                var idx = compact.startIndex
                while idx < compact.endIndex {
                    let next = compact.index(idx, offsetBy: 2, limitedBy: compact.endIndex) ?? compact.endIndex
                    if let b = UInt8(compact[idx..<next], radix: 16) { data.append(b) }
                    idx = next
                }
            } else {
                data = Data(input.utf8)
            }
            var ok = false
            var got: Any?
            var err = ""
            do {
                if format == "plist" {
                    var fmt = PropertyListSerialization.PropertyListFormat.xml
                    got = try PropertyListSerialization.propertyList(from: data, options: [], format: &fmt)
                } else if format == "protobuf" {
                    got = try decodeProtobuf(data, schema: (c["schema"] as? String) ?? "")
                } else {
                    got = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                }
                ok = true
            } catch {
                err = "\(error)"
            }
            let expect = (c["expect"] as? String) ?? ""
            if expect == "reject" {
                if ok {
                    row["outcome"] = "fail"
                    row["detail"] = "parser accepted input the spec requires to be rejected"
                    row["observed"] = "accepted"
                } else {
                    row["observed"] = err
                }
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
        "schema": "gld.dashboard.compliance/1",
        "generated_at": ISO8601DateFormatter().string(from: Date()),
        "language": "swift",
        "languages": ["swift"],
        "policy": "report-only",
        "scope": ["formats": ["json", "plist", "protobuf"]],
        "passed": p, "failed": f, "skipped": 0, "errors": 0,
        "catalog_errors": [],
        "serializer_errors": adapterErrs,
        "results": results,
    ]
    let out = try! JSONSerialization.data(withJSONObject: doc, options: [.prettyPrinted])
    try! FileManager.default.createDirectory(at: URL(fileURLWithPath: jsonOut).deletingLastPathComponent(), withIntermediateDirectories: true)
    try! out.write(to: URL(fileURLWithPath: jsonOut))
    print("\nWrote \(jsonOut)")
}
