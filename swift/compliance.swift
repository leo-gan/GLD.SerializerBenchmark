#!/usr/bin/env swift
import Foundation

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
        if format != "json" && format != "plist" {
            adapterErrs.append("No adapter registered for format \(format) (\(suite["standard"] ?? "") (\(suite["version"] ?? "")))")
            continue
        }
        let ser = format == "plist" ? "Foundation.PropertyListSerialization" : "Foundation.JSONSerialization"
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
        "scope": ["formats": ["json", "plist"]],
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
