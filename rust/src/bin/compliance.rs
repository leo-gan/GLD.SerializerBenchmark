//! Rust compliance runner — same catalog as Python.
//!
//!   cargo run --quiet --bin compliance -- --json-out ../../logs/compliance/rust.json

use anyhow::{Context, Result};
use std::str::FromStr;
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

struct Adapter {
    name: &'static str,
    format: &'static str,
    version: String,
    decode: fn(&[u8], &str) -> Result<Value>,
}

fn main() -> Result<()> {
    std::thread::Builder::new()
        .name("compliance".into())
        .stack_size(16 * 1024 * 1024)
        .spawn(run)
        .context("spawn")?
        .join()
        .map_err(|_| anyhow::anyhow!("compliance thread panicked"))?
}

fn run() -> Result<()> {
    let mut json_out = None::<PathBuf>;
    let mut formats: Vec<String> = Vec::new();
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--json-out" | "-o" => json_out = args.next().map(PathBuf::from),
            "--format" | "-f" => {
                if let Some(f) = args.next() {
                    formats.push(f.to_lowercase());
                }
            }
            _ => {}
        }
    }
    let root = repo_root()?;
    let mut suites = load_suites(&root.join("compliance/data"))?;
    if !formats.is_empty() {
        suites.retain(|s| formats.iter().any(|f| f == s["format"].as_str().unwrap_or("")));
    }
    let adapters = builtin();
    let mut adapter_errs = Vec::new();
    let adapters = filter_by_mapping(&root, "rust", adapters, &mut adapter_errs);
    let mut by_fmt: BTreeMap<&str, Vec<&Adapter>> = BTreeMap::new();
    for a in &adapters {
        by_fmt.entry(a.format).or_default().push(a);
    }
    let mut results = Vec::new();
    for suite in &suites {
        let fmt = suite["format"].as_str().unwrap_or("");
        let chosen = by_fmt.get(fmt).cloned().unwrap_or_default();
        if chosen.is_empty() {
            adapter_errs.push(format!(
                "No adapter registered for format {} ({} ({}))",
                fmt,
                suite["standard"].as_str().unwrap_or(""),
                suite["version"].as_str().unwrap_or("")
            ));
            continue;
        }
        let cases = suite["cases"].as_array().cloned().unwrap_or_default();
        for a in chosen {
            for c in &cases {
                results.push(run_one(suite, c, a));
            }
        }
    }
    print_summary(&results, &adapter_errs);
    if let Some(path) = json_out {
        write_report(&path, &results, &adapter_errs)?;
        println!("\nWrote {}", path.display());
    }
    Ok(())
}

fn filter_by_mapping(root: &Path, language: &str, adapters: Vec<Adapter>, errs: &mut Vec<String>) -> Vec<Adapter> {
    let path = root.join("compliance/serializer-standards.json");
    let raw = match fs::read_to_string(&path) {
        Ok(s) => s,
        Err(e) => {
            errs.push(format!("missing mapping file: {e}"));
            return adapters;
        }
    };
    let doc: Value = match serde_json::from_str(&raw) {
        Ok(v) => v,
        Err(e) => {
            errs.push(format!("invalid mapping file: {e}"));
            return adapters;
        }
    };
    let mut allow = std::collections::HashSet::<String>::new();
    if let Some(slice) = doc.pointer(&format!("/languages/{language}")).and_then(|v| v.as_object()) {
        for (name, fmts) in slice {
            if let Some(arr) = fmts.as_array() {
                for fmt in arr {
                    if let Some(f) = fmt.as_str() {
                        allow.insert(format!("{name}\0{f}"));
                    }
                }
            }
        }
    }
    adapters
        .into_iter()
        .filter(|a| allow.contains(&format!("{}\0{}", a.name, a.format)))
        .collect()
}

fn repo_root() -> Result<PathBuf> {
    let mut dir = std::env::current_dir()?;
    for _ in 0..8 {
        if dir.join("compliance/data").is_dir() {
            return Ok(dir);
        }
        if !dir.pop() {
            break;
        }
    }
    anyhow::bail!("cannot locate compliance/data")
}

fn load_suites(root: &Path) -> Result<Vec<Value>> {
    let mut suites = Vec::new();
    for fmt in fs::read_dir(root).with_context(|| format!("read {}", root.display()))? {
        let fmt = fmt?;
        if !fmt.file_type()?.is_dir() {
            continue;
        }
        for ent in fs::read_dir(fmt.path())? {
            let ent = ent?;
            let name = ent.file_name().to_string_lossy().into_owned();
            if !name.ends_with(".json") || name.starts_with('_') {
                continue;
            }
            let raw: Value = serde_json::from_str(&fs::read_to_string(ent.path())?)?;
            if raw.get("cases").and_then(|c| c.as_array()).map(|a| !a.is_empty()).unwrap_or(false) {
                suites.push(raw);
            }
        }
    }
    if suites.is_empty() {
        anyhow::bail!("no compliance suites under {}", root.display());
    }
    Ok(suites)
}

fn input_bytes(c: &Value) -> Result<Vec<u8>> {
    let enc = c.get("input_encoding").and_then(|v| v.as_str()).unwrap_or("utf-8");
    let input = c.get("input").and_then(|v| v.as_str()).unwrap_or("");
    if enc == "hex" {
        let compact: String = input.chars().filter(|ch| !ch.is_whitespace()).collect();
        if compact.is_empty() {
            return Ok(Vec::new());
        }
        return Ok(hex_decode(&compact)?);
    }
    Ok(input.as_bytes().to_vec())
}

fn too_deep(b: &[u8]) -> bool {
    b.len() > 200_000 || b.iter().filter(|&&c| c == b'[' || c == b'{').count() > 4_000
}

fn hex_decode(s: &str) -> Result<Vec<u8>> {
    if s.len() % 2 != 0 {
        anyhow::bail!("odd hex");
    }
    let mut out = Vec::with_capacity(s.len() / 2);
    let bytes = s.as_bytes();
    for i in (0..bytes.len()).step_by(2) {
        let n = u8::from_str_radix(std::str::from_utf8(&bytes[i..i + 2])?, 16)?;
        out.push(n);
    }
    Ok(out)
}

include!(concat!(env!("OUT_DIR"), "/dep_versions.rs"));

fn builtin() -> Vec<Adapter> {
    vec![
        Adapter {
            name: "serde_json",
            format: "json",
            version: crate_version("serde_json").to_string(),
            decode: |b, _| {
                if too_deep(b) {
                    anyhow::bail!("input too nested for this runner");
                }
                Ok(serde_json::from_slice(b)?)
            },
        },
        Adapter {
            name: "sonic-rs",
            format: "json",
            version: crate_version("sonic-rs").to_string(),
            decode: |b, _| {
                if too_deep(b) {
                    anyhow::bail!("input too nested for this runner");
                }
                let v: serde_json::Value = sonic_rs::from_slice(b).map_err(|e| anyhow::anyhow!("{e}"))?;
                Ok(v)
            },
        },
        Adapter {
            name: "serde_yaml",
            format: "yaml",
            version: crate_version("serde_yaml").to_string(),
            decode: |b, _| {
                let v: serde_json::Value = serde_yaml::from_slice(b)?;
                Ok(v)
            },
        },
        Adapter {
            name: "ciborium",
            format: "cbor",
            version: crate_version("ciborium").to_string(),
            decode: |b, _| {
                let v: serde_json::Value = ciborium::from_reader(b).map_err(|e| anyhow::anyhow!("{e}"))?;
                Ok(v)
            },
        },
        Adapter {
            name: "rmp-serde",
            format: "msgpack",
            version: crate_version("rmp-serde").to_string(),
            decode: |b, _| {
                let v: serde_json::Value = rmp_serde::from_slice(b).map_err(|e| anyhow::anyhow!("{e}"))?;
                Ok(v)
            },
        },
        Adapter {
            name: "bson",
            format: "bson",
            version: crate_version("bson").to_string(),
            decode: |b, _| {
                let doc = bson::Document::from_reader(&mut std::io::Cursor::new(b))?;
                Ok(serde_json::to_value(doc)?)
            },
        },
        Adapter {
            name: "flexbuffers",
            format: "flatbuffers",
            version: crate_version("flexbuffers").to_string(),
            decode: |b, _| {
                let _ = flexbuffers::Reader::get_root(b).map_err(|e| anyhow::anyhow!("{e}"))?;
                Ok(Value::Null)
            },
        },
        Adapter {
            name: "prost",
            format: "protobuf",
            version: crate_version("prost").to_string(),
            decode: decode_protobuf,
        },
        Adapter {
            name: "simd-json",
            format: "json",
            version: crate_version("simd-json").to_string(),
            decode: |b, _| {
                if too_deep(b) {
                    anyhow::bail!("input too nested for this runner");
                }
                let mut owned = b.to_vec();
                let v: serde_json::Value = simd_json::serde::from_slice(&mut owned)?;
                Ok(v)
            },
        },
        Adapter {
            name: "minicbor",
            format: "cbor",
            version: crate_version("minicbor").to_string(),
            decode: |b, _| {
                let mut dec = minicbor::Decoder::new(b);
                dec.skip().map_err(|e| anyhow::anyhow!("{e}"))?;
                Ok(Value::Null)
            },
        },
        Adapter {
            name: "serde_avro_fast",
            format: "avro",
            version: crate_version("serde_avro_fast").to_string(),
            decode: decode_avro,
        },
    ]
}

fn avro_schema_json(schema: &str) -> String {
    if schema.is_empty() {
        return "\"int\"".into();
    }
    let c = schema.as_bytes()[0];
    if c == b'{' || c == b'[' || c == b'"' {
        schema.to_string()
    } else {
        format!("\"{schema}\"")
    }
}

fn decode_avro(b: &[u8], schema: &str) -> anyhow::Result<Value> {
    let json = avro_schema_json(schema);
    let schema = serde_avro_fast::Schema::from_str(&json)?;
    let v: serde_json::Value = serde_avro_fast::from_datum_slice(b, &schema)?;
    Ok(v)
}

#[derive(Clone, PartialEq, prost::Message)]
struct PbDoc {
    #[prost(int32, tag = "1")]
    n: i32,
    #[prost(string, tag = "2")]
    s: String,
    #[prost(bool, tag = "3")]
    ok: bool,
    #[prost(int32, repeated, tag = "4")]
    tags: Vec<i32>,
}

fn decode_protobuf(b: &[u8], schema: &str) -> Result<Value> {
    let doc = if schema == "json" {
        pb_from_json(b)?
    } else {
        prost::Message::decode(b).map_err(|e| anyhow::anyhow!("{e}"))?
    };
    Ok(json!({"n": doc.n, "s": doc.s, "ok": doc.ok, "tags": doc.tags}))
}

fn pb_from_json(b: &[u8]) -> Result<PbDoc> {
    let v: Value = serde_json::from_slice(b)?;
    let obj = v.as_object().context("proto3 JSON message must be an object")?;
    let mut doc = PbDoc::default();
    if let Some(n) = obj.get("n") {
        if !n.is_null() {
            doc.n = pb_i32(n)?;
        }
    }
    if let Some(s) = obj.get("s") {
        if !s.is_null() {
            doc.s = s.as_str().context("s must be a string")?.to_string();
        }
    }
    if let Some(ok) = obj.get("ok") {
        if !ok.is_null() {
            doc.ok = ok.as_bool().context("ok must be a bool")?;
        }
    }
    if let Some(tags) = obj.get("tags") {
        if !tags.is_null() {
            let arr = tags.as_array().context("tags must be an array")?;
            for t in arr {
                doc.tags.push(pb_i32(t)?);
            }
        }
    }
    Ok(doc)
}

fn pb_i32(v: &Value) -> Result<i32> {
    if let Some(n) = v.as_i64() {
        return i32::try_from(n).context("int32 range");
    }
    if let Some(n) = v.as_u64() {
        return i32::try_from(n).context("int32 range");
    }
    if let Some(s) = v.as_str() {
        return s.parse::<i32>().context("int32 decimal string");
    }
    anyhow::bail!("int32 must be a number or digit string")
}

fn run_one(suite: &Value, c: &Value, a: &Adapter) -> Value {
    let mut base = json!({
        "id": c["id"], "language": "rust", "serializer": a.name, "serializer_version": a.version,
        "format": suite["format"], "standard": suite["standard"], "standard_url": suite["standard_url"],
        "version": suite["version"],
        "version_key": format!("{}.{}", suite["format"].as_str().unwrap_or(""), suite["version"].as_str().unwrap_or("")),
        "requirement": c["requirement"], "expect": c["expect"], "section": c["section"],
        "section_title": c["section_title"], "section_url": c["section_url"], "paragraph": c["paragraph"],
        "title": c["title"], "input": c["input"],
        "input_encoding": c.get("input_encoding").and_then(|v| v.as_str()).unwrap_or("utf-8"),
        "detail": "", "observed": "", "outcome": "pass",
    });
    let raw = match input_bytes(c) {
        Ok(b) => b,
        Err(e) => {
            base["outcome"] = json!("error");
            base["observed"] = json!(e.to_string());
            return base;
        }
    };
    let schema = c.get("schema").and_then(|v| v.as_str()).unwrap_or("");
    let decoded = (a.decode)(&raw, schema);
    let expect = c["expect"].as_str().unwrap_or("");
    match (expect, decoded) {
        ("any", Ok(v)) => {
            base["observed"] = json!(preview(&v));
        }
        ("any", Err(e)) => {
            base["observed"] = json!(e.to_string());
        }
        ("reject", Err(e)) => {
            base["observed"] = json!(e.to_string());
        }
        ("reject", Ok(v)) => {
            base["outcome"] = json!("fail");
            base["detail"] = json!("parser accepted input the spec requires to be rejected");
            base["observed"] = json!(format!("accepted as {}", preview(&v)));
        }
        (_, Err(e)) => {
            base["outcome"] = json!("fail");
            base["detail"] = json!("parser rejected input the spec requires to accept");
            base["observed"] = json!(e.to_string());
        }
        (_, Ok(v)) => {
            if c.get("decoded").is_some() && !values_equal(&c["decoded"], &v) {
                base["outcome"] = json!("fail");
                base["detail"] = json!("decoded value does not match the catalog case");
                base["observed"] = json!(format!("got {}, want {}", preview(&v), preview(&c["decoded"])));
            } else {
                base["observed"] = json!(preview(&v));
            }
        }
    }
    base
}

fn values_equal(expected: &Value, observed: &Value) -> bool {
    if let Some(obj) = expected.as_object() {
        if obj.len() == 1 {
            if let Some(hx) = obj.get("$hex").and_then(|v| v.as_str()) {
                if let Some(s) = observed.as_str() {
                    return s.as_bytes() == hex_decode(&hx.replace(' ', "")).ok().as_deref().unwrap_or(&[]);
                }
                return false;
            }
        }
    }
    if expected.is_null() {
        return observed.is_null();
    }
    if expected.is_boolean() {
        return expected == observed;
    }
    if expected.is_number() && observed.is_number() {
        return expected.as_f64() == observed.as_f64();
    }
    if expected.is_string() {
        return expected == observed;
    }
    if let (Some(a), Some(b)) = (expected.as_array(), observed.as_array()) {
        return a.len() == b.len() && a.iter().zip(b).all(|(x, y)| values_equal(x, y));
    }
    if let (Some(a), Some(b)) = (expected.as_object(), observed.as_object()) {
        return a.len() == b.len() && a.iter().all(|(k, v)| b.get(k).is_some_and(|o| values_equal(v, o)));
    }
    expected == observed
}

fn preview(v: &Value) -> String {
    let s = v.to_string();
    if s.len() <= 120 {
        return s;
    }
    let end = s
        .char_indices()
        .map(|(i, _)| i)
        .take_while(|i| *i <= 117)
        .last()
        .unwrap_or(0);
    format!("{}...", &s[..end])
}

fn print_summary(results: &[Value], adapter_errs: &[String]) {
    let mut p = 0;
    let mut f = 0;
    let mut s = 0;
    let mut e = 0;
    let mut by: BTreeMap<String, [i32; 3]> = BTreeMap::new();
    for r in results {
        match r["outcome"].as_str().unwrap_or("") {
            "pass" => p += 1,
            "fail" => f += 1,
            "skip" => s += 1,
            _ => e += 1,
        }
        let key = format!(
            "{} ({}) × {}",
            r["standard"].as_str().unwrap_or(""),
            r["version"].as_str().unwrap_or(""),
            r["serializer"].as_str().unwrap_or("")
        );
        let c = by.entry(key).or_insert([0, 0, 0]);
        match r["outcome"].as_str().unwrap_or("") {
            "pass" => c[0] += 1,
            "fail" => c[1] += 1,
            _ => c[2] += 1,
        }
    }
    println!("Serialization compliance (library deviations are catalogued, not a red build)");
    println!("  {p} pass  {f} fail  {s} skip  {e} error  {} total", results.len());
    if !adapter_errs.is_empty() {
        println!("  Adapter errors:");
        for a in adapter_errs {
            println!("    - {a}");
        }
    }
    println!("  By suite × adapter:");
    for (k, c) in &by {
        println!("    {k}: {} pass, {} fail, {} skip", c[0], c[1], c[2]);
    }
}

fn write_report(path: &Path, results: &[Value], adapter_errs: &[String]) -> Result<()> {
    let mut p = 0;
    let mut f = 0;
    let mut s = 0;
    let mut e = 0;
    let mut fmts = BTreeMap::new();
    for r in results {
        match r["outcome"].as_str().unwrap_or("") {
            "pass" => p += 1,
            "fail" => f += 1,
            "skip" => s += 1,
            _ => e += 1,
        }
        if let Some(fmt) = r["format"].as_str() {
            fmts.insert(fmt.to_string(), true);
        }
    }
    let doc = json!({
        "schema": "gld.dashboard.compliance/1",
        "generated_at": "",
        "language": "rust",
        "languages": ["rust"],
        "policy": "report-only",
        "scope": { "formats": fmts.keys().cloned().collect::<Vec<_>>() },
        "passed": p, "failed": f, "skipped": s, "errors": e,
        "catalog_errors": [],
        "serializer_errors": adapter_errs,
        "results": results,
    });
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, serde_json::to_string_pretty(&doc)? + "\n")?;
    Ok(())
}
