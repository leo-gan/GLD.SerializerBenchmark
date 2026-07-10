//! Data Model v2 path: cells from resolve_run_config.py + codecs on serde_json::Value.

use crate::csv_log::CsvLogger;
use crate::data_v2;
use anyhow::{Context, Result};
use serde_json::Value;
use std::path::Path;
use std::process::Command;
use std::time::Instant;

#[derive(Debug, Clone)]
struct Cell {
    type_id: String,
    type_config_hash: String,
    instance_count: i32,
    value: Value,
}

fn load_cells(run_config: &str, seed: u64) -> Result<(Vec<Cell>, Vec<String>)> {
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let script = repo.join("scripts/resolve_run_config.py");
    let cfg = if run_config.is_empty() {
        repo.join("config/library/default.yaml")
    } else {
        let p = Path::new(run_config);
        if p.is_absolute() {
            p.to_path_buf()
        } else {
            let candidate = repo.join(run_config.trim_start_matches("./"));
            if candidate.is_file() {
                candidate
            } else {
                std::env::current_dir()
                    .map(|c| c.join(p))
                    .unwrap_or_else(|_| p.to_path_buf())
            }
        }
    };
    let out = Command::new("python3")
        .arg(&script)
        .arg(&cfg)
        .arg("--seed")
        .arg(seed.to_string())
        .env("PYTHONPATH", repo.join("analysis/src"))
        .current_dir(repo)
        .output()
        .context("spawn resolve_run_config")?;
    if !out.status.success() {
        anyhow::bail!(
            "resolve_run_config failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );
    }
    let doc: Value = serde_json::from_slice(&out.stdout)?;
    let modes = doc["execution"]["io_modes"]
        .as_array()
        .map(|a| {
            a.iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect::<Vec<_>>()
        })
        .unwrap_or_else(|| vec!["bytes".into()]);
    let cells = doc["cells"].as_array().context("cells")?;
    let mut out_cells = Vec::new();
    for c in cells {
        let type_id = c["type_id"].as_str().unwrap_or("").to_string();
        let n = c["data_type_instance_count"].as_i64().unwrap_or(1) as i32;
        let hash = c["type_config_hash"].as_str().unwrap_or("").to_string();
        let children = c["type_config"]["children"].as_i64().unwrap_or(8) as i32;
        let points = c["type_config"]["points"].as_i64().unwrap_or(32) as i32;
        let count = c["type_config"]["count"].as_i64().unwrap_or(32) as i32;
        let attrs = c["type_config"]["attr_count"].as_i64().unwrap_or(4) as i32;
        let value = if n <= 1 {
            data_v2::make_one(&type_id, seed, 0, children, points, count, attrs)
        } else {
            let arr: Vec<Value> = (0..n)
                .map(|i| data_v2::make_one(&type_id, seed, i, children, points, count, attrs))
                .collect();
            Value::Array(arr)
        };
        out_cells.push(Cell {
            type_id,
            type_config_hash: hash,
            instance_count: n.max(1),
            value,
        });
    }
    Ok((out_cells, modes))
}

struct Codec {
    name: &'static str,
    version: &'static str,
    encode: fn(&Value) -> Result<Vec<u8>>,
    decode: fn(&[u8]) -> Result<Value>,
}

fn codecs() -> Vec<Codec> {
    vec![
        Codec {
            name: "serde_json",
            version: "1",
            encode: |v| Ok(serde_json::to_vec(v)?),
            decode: |b| Ok(serde_json::from_slice(b)?),
        },
        Codec {
            name: "sonic-rs",
            version: "0.3",
            encode: |v| Ok(sonic_rs::to_vec(v)?),
            decode: |b| Ok(sonic_rs::from_slice(b)?),
        },
        Codec {
            name: "rmp-serde",
            version: "1",
            encode: |v| Ok(rmp_serde::to_vec(v)?),
            decode: |b| Ok(rmp_serde::from_slice(b)?),
        },
        Codec {
            name: "ciborium",
            version: "0.2",
            encode: |v| {
                let mut buf = Vec::new();
                ciborium::into_writer(v, &mut buf)?;
                Ok(buf)
            },
            decode: |b| Ok(ciborium::from_reader(b)?),
        },
        // bincode/postcard/bitcode do not support serde_json::Value (Any) reliably.
        Codec {
            name: "bson",
            version: "2",
            encode: |v| {
                let doc = match v {
                    Value::Object(_) => v.clone(),
                    other => serde_json::json!({ "v": other }),
                };
                Ok(bson::to_vec(&doc)?)
            },
            decode: |b| {
                let v: Value = bson::from_slice(b)?;
                if let Value::Object(mut m) = v {
                    if m.len() == 1 {
                        if let Some(inner) = m.remove("v") {
                            return Ok(inner);
                        }
                    }
                    Ok(Value::Object(m))
                } else {
                    Ok(v)
                }
            },
        },
    ]
}

fn json_eq(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::Null, Value::Null) => true,
        (Value::Bool(x), Value::Bool(y)) => x == y,
        (Value::Number(x), Value::Number(y)) => {
            if x == y {
                return true;
            }
            match (x.as_f64(), y.as_f64()) {
                (Some(xf), Some(yf)) => (xf - yf).abs() < 1e-6,
                _ => false,
            }
        }
        (Value::String(x), Value::String(y)) => x == y,
        (Value::Array(x), Value::Array(y)) => {
            x.len() == y.len() && x.iter().zip(y.iter()).all(|(p, q)| json_eq(p, q))
        }
        (Value::Object(x), Value::Object(y)) => {
            // tolerate missing default-ish keys
            for (k, v) in x {
                match y.get(k) {
                    Some(w) => {
                        if !json_eq(v, w) {
                            return false;
                        }
                    }
                    None => {
                        if !is_defaultish(v) {
                            return false;
                        }
                    }
                }
            }
            true
        }
        _ => false,
    }
}

fn is_defaultish(v: &Value) -> bool {
    match v {
        Value::Null => true,
        Value::Bool(false) => true,
        Value::Number(n) => n.as_f64() == Some(0.0),
        Value::String(s) => s.is_empty(),
        Value::Array(a) => a.is_empty(),
        Value::Object(o) => o.is_empty(),
        _ => false,
    }
}

pub fn run_v2(
    repetitions: u32,
    log_path: &Path,
    ser_filter: Option<&str>,
    data_filter: Option<&str>,
) -> Result<()> {
    let seed: u64 = std::env::var("BENCHMARK_SEED")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(42);
    let run_cfg = std::env::var("BENCHMARK_RUN_CONFIG").unwrap_or_default();
    let (mut cells, modes) = load_cells(&run_cfg, seed)?;
    if let Some(f) = data_filter {
        let f = f.to_lowercase();
        cells.retain(|c| c.type_id.to_lowercase().contains(&f));
    }
    let mut codecs = codecs();
    if let Some(f) = ser_filter {
        let f = f.to_lowercase();
        codecs.retain(|c| c.name.to_lowercase().contains(&f));
    }

    let mut logger = CsvLogger::create(log_path)?;
    println!(
        "[PROGRESS] Rust Data Model v2: {} codecs, {} cells, {} reps, modes={:?}",
        codecs.len(),
        cells.len(),
        repetitions,
        modes
    );

    for cell in &cells {
        println!(
            "[PROGRESS] Cell {} N={}",
            cell.type_id, cell.instance_count
        );
        for codec in &codecs {
            let mut had_error = false;
            for i in 0..repetitions {
                if had_error {
                    break;
                }
                let measured = (|| -> Result<(u128, u128, usize)> {
                    let t0 = Instant::now();
                    let buf = (codec.encode)(&cell.value)?;
                    let ser_ns = t0.elapsed().as_nanos();
                    let t1 = Instant::now();
                    let out = (codec.decode)(&buf)?;
                    let deser_ns = t1.elapsed().as_nanos();
                    if !json_eq(&cell.value, &out) {
                        anyhow::bail!("fidelity");
                    }
                    Ok((ser_ns, deser_ns, buf.len()))
                })();
                match measured {
                    Ok((ser_ns, deser_ns, size)) => {
                        logger.write_row_v2(
                            "bytes",
                            &cell.type_id,
                            repetitions,
                            i,
                            codec.name,
                            ser_ns,
                            deser_ns,
                            size,
                            1.0,
                            codec.version,
                            "serde",
                            "adapted",
                            cell.instance_count as u32,
                            &cell.type_config_hash,
                        )?;
                    }
                    Err(e) => {
                        eprintln!(
                            "[ERROR] {} / {} : {}",
                            codec.name, cell.type_id, e
                        );
                        had_error = true;
                    }
                }
            }
        }
    }
    logger.flush()?;
    println!("[PROGRESS] Complete. Results: {}", log_path.display());
    Ok(())
}
