//! Data Model v2 path: cells from resolve_run_config.py + full serializer registry.
//!
//! Schemaless codecs (serde) operate on `Fixture` variants populated from v2
//! generators. Typed codecs (minicbor/rkyv/…) map v2 shapes onto the closest
//! existing concrete structs so the historical 15-serializer set is preserved.

use crate::csv_log::CsvLogger;
use crate::data::{
    Fixture, SimpleObject, StringArrayObject, TelemetryData, Edi835, Claim, ServiceLine,
};
use crate::data_v2;
use crate::serializers::{all_serializers, BenchSerializer};
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
    /// One fixture per instance (length == instance_count). N=1 is a single-element vec.
    fixtures: Vec<Fixture>,
}

impl Cell {
    fn primary(&self) -> &Fixture {
        &self.fixtures[0]
    }
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
        let n = n.max(1);
        // Build all N instances (W×C batch axis). Must not collapse N>1 to a single item
        // while still labeling CSV DataTypeInstanceCount=N (that made Rust look 100× too fast).
        let mut fixtures = Vec::with_capacity(n as usize);
        for i in 0..n {
            let value = data_v2::make_one(&type_id, seed, i, children, points, count, attrs);
            fixtures.push(value_to_fixture(&type_id, &value)?);
        }
        out_cells.push(Cell {
            type_id,
            type_config_hash: hash,
            instance_count: n,
            fixtures,
        });
    }
    Ok((out_cells, modes))
}

/// Map v2 JSON values onto existing Fixture variants so all 15 codecs can run.
fn value_to_fixture(type_id: &str, v: &Value) -> Result<Fixture> {
    match type_id {
        "message" => {
            let m: data_v2::Message = serde_json::from_value(v.clone())?;
            Ok(Fixture::Simple(SimpleObject {
                id: m.f_int32,
                name: m.f_string,
                timestamp: format!("{}", m.f_int64),
                is_active: m.f_bool,
            }))
        }
        "telemetry" => {
            let t: data_v2::Telemetry = serde_json::from_value(v.clone())?;
            Ok(Fixture::Telemetry(TelemetryData {
                id: t.source.clone(),
                data_source: t.source,
                time_stamp: format!("{}", t.ts),
                param1: t.values.first().map(|x| *x as i32).unwrap_or(0),
                param2: t.tags.len() as i32,
                measurements: t.values,
                associated_problem_id: 0,
                associated_log_id: 0,
                was_processed: true,
            }))
        }
        "strings" => {
            let s: data_v2::Strings = serde_json::from_value(v.clone())?;
            Ok(Fixture::StringArray(StringArrayObject { items: s.items }))
        }
        "document" => {
            let d: data_v2::Document = serde_json::from_value(v.clone())?;
            let claims: Vec<Claim> = d
                .items
                .iter()
                .take(4)
                .map(|it| Claim {
                    claim_id: it.sku.clone(),
                    patient_name: d.id.clone(),
                    total_charge: it.price_minor as f64 / 100.0,
                    payment_amount: it.qty as f64,
                    lines: vec![ServiceLine {
                        service_code: it.sku.clone(),
                        charge_amount: it.price_minor as f64 / 100.0,
                        adjudicated_amount: it.qty as f64,
                    }],
                })
                .collect();
            Ok(Fixture::Edi(Edi835 {
                payer_name: d.meta.region,
                payee_name: d.id,
                payment_date: format!("{}", d.status),
                total_actual_amount: claims.iter().map(|c| c.total_charge).sum(),
                transaction_control_number: format!("v{}", d.meta.version),
                claims,
            }))
        }
        "event" => {
            let e: data_v2::Event = serde_json::from_value(v.clone())?;
            Ok(Fixture::Simple(SimpleObject {
                id: e.occurred_at as i32,
                name: e.event_type,
                timestamp: e.event_id,
                is_active: !e.producer.is_empty(),
            }))
        }
        other => anyhow::bail!("unknown v2 type_id {other}"),
    }
}

/// Encode one cell: N=1 → raw codec bytes; N>1 → u32 LE count + (u32 LE len + payload)×N.
/// Matches C `bench_serialize_cell` so DataTypeInstanceCount reflects real batch work.
fn serialize_cell_bytes(
    ser: &mut dyn BenchSerializer,
    fixtures: &[Fixture],
) -> Result<Vec<u8>> {
    if fixtures.is_empty() {
        anyhow::bail!("empty batch");
    }
    if fixtures.len() == 1 {
        return ser.serialize_bytes(&fixtures[0]);
    }
    let n = fixtures.len() as u32;
    let mut out = Vec::with_capacity(4 + fixtures.len() * 64);
    out.extend_from_slice(&n.to_le_bytes());
    for fx in fixtures {
        let part = ser.serialize_bytes(fx)?;
        let len = part.len() as u32;
        out.extend_from_slice(&len.to_le_bytes());
        out.extend_from_slice(&part);
    }
    Ok(out)
}

fn deserialize_cell_bytes(
    ser: &mut dyn BenchSerializer,
    buf: &[u8],
    expected: &[Fixture],
) -> Result<Vec<Fixture>> {
    if expected.len() == 1 {
        return Ok(vec![ser.deserialize_bytes(buf)?]);
    }
    if buf.len() < 4 {
        anyhow::bail!("batch frame too short");
    }
    let n = u32::from_le_bytes(buf[0..4].try_into()? ) as usize;
    if n != expected.len() {
        anyhow::bail!("batch count {n} != expected {}", expected.len());
    }
    let mut o = 4usize;
    let mut out = Vec::with_capacity(n);
    for _ in 0..n {
        if o + 4 > buf.len() {
            anyhow::bail!("truncated batch frame");
        }
        let item_len = u32::from_le_bytes(buf[o..o + 4].try_into()?) as usize;
        o += 4;
        if o + item_len > buf.len() {
            anyhow::bail!("truncated batch payload");
        }
        out.push(ser.deserialize_bytes(&buf[o..o + item_len])?);
        o += item_len;
    }
    Ok(out)
}

fn serialize_cell_stream(
    ser: &mut dyn BenchSerializer,
    fixtures: &[Fixture],
    w: &mut dyn std::io::Write,
) -> Result<usize> {
    // Adapted: build full cell bytes then write (stream size = framed payload length).
    let data = serialize_cell_bytes(ser, fixtures)?;
    w.write_all(&data)?;
    Ok(data.len())
}

fn deserialize_cell_stream(
    ser: &mut dyn BenchSerializer,
    buf: &[u8],
    expected: &[Fixture],
) -> Result<Vec<Fixture>> {
    deserialize_cell_bytes(ser, buf, expected)
}

fn check_batch_fidelity(expected: &[Fixture], got: &[Fixture]) -> Result<()> {
    if expected.len() != got.len() {
        anyhow::bail!(
            "fidelity batch len {} != {}",
            got.len(),
            expected.len()
        );
    }
    for (a, b) in expected.iter().zip(got.iter()) {
        if a.name() != b.name() {
            anyhow::bail!("fidelity kind mismatch {} vs {}", a.name(), b.name());
        }
    }
    Ok(())
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
    let mut serializers = all_serializers();
    if let Some(f) = ser_filter {
        let f = f.to_lowercase();
        serializers.retain(|s| s.name().to_lowercase().contains(&f));
    }

    let mut logger = CsvLogger::create(log_path)?;
    println!(
        "[PROGRESS] Rust Data Model v2: {} serializers, {} cells, {} reps, modes={:?}",
        serializers.len(),
        cells.len(),
        repetitions,
        modes
    );

    for cell in &cells {
        println!(
            "[PROGRESS] Cell {} N={}",
            cell.type_id, cell.instance_count
        );
        let primary = cell.primary();
        for ser in serializers.iter_mut() {
            if !ser.supports(primary.name()) {
                // still try — some support by type_id only
                if !ser.supports(&cell.type_id) {
                    continue;
                }
            }
            // Prepare on first instance shape (codecs cache type state).
            if let Err(e) = ser.prepare(primary) {
                eprintln!("[ERROR] prepare {} / {} : {}", ser.name(), cell.type_id, e);
                continue;
            }
            let mode_list: Vec<&str> = if modes.is_empty() {
                vec!["bytes"]
            } else {
                modes.iter().map(|s| s.as_str()).collect()
            };
            for mode in mode_list {
                let mut had_error = false;
                for i in 0..repetitions {
                    if had_error {
                        break;
                    }
                    let measured = (|| -> Result<(u128, u128, usize)> {
                        // Batch cells: frame N single-item payloads (same as C harness).
                        // N=1 is a thin passthrough — no framing overhead.
                        if mode == "stream" {
                            let mut buf = Vec::new();
                            let t0 = Instant::now();
                            let size = serialize_cell_stream(ser.as_mut(), &cell.fixtures, &mut buf)?;
                            let ser_ns = t0.elapsed().as_nanos();
                            let t1 = Instant::now();
                            let outs = deserialize_cell_stream(ser.as_mut(), &buf, &cell.fixtures)?;
                            let deser_ns = t1.elapsed().as_nanos();
                            check_batch_fidelity(&cell.fixtures, &outs)?;
                            Ok((ser_ns, deser_ns, size))
                        } else {
                            let t0 = Instant::now();
                            let buf = serialize_cell_bytes(ser.as_mut(), &cell.fixtures)?;
                            let ser_ns = t0.elapsed().as_nanos();
                            let t1 = Instant::now();
                            let outs = deserialize_cell_bytes(ser.as_mut(), &buf, &cell.fixtures)?;
                            let deser_ns = t1.elapsed().as_nanos();
                            check_batch_fidelity(&cell.fixtures, &outs)?;
                            Ok((ser_ns, deser_ns, buf.len()))
                        }
                    })();
                    match measured {
                        Ok((ser_ns, deser_ns, size)) => {
                            logger.write_row_v2(
                                mode,
                                &cell.type_id,
                                repetitions,
                                i,
                                ser.name(),
                                ser_ns,
                                deser_ns,
                                size,
                                1.0,
                                ser.version(),
                                "serde",
                                "adapted",
                                cell.instance_count as u32,
                                &cell.type_config_hash,
                            )?;
                        }
                        Err(e) => {
                            eprintln!(
                                "[ERROR] {} / {} / {} : {}",
                                ser.name(),
                                cell.type_id,
                                mode,
                                e
                            );
                            had_error = true;
                        }
                    }
                }
            }
        }
    }
    logger.flush()?;
    println!("[PROGRESS] Complete. Results: {}", log_path.display());
    Ok(())
}
