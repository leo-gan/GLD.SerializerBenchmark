//! Data Model v2 path: cells from resolve_run_config.py + full serializer registry.
//!
//! Builds first-class V2 `Fixture` variants (Message/Document/Telemetry/Strings/Event)
//! directly from generators.
//!
//! ## Timing contract (issue #59)
//!
//! - Harness owns a reusable serialize buffer; `clear()` before each timed encode.
//! - Capacity is preserved across reps so cold allocation is mostly warmup (rep 0).
//! - [`std::hint::black_box`] on timed inputs/outputs prevents optimization leakage.
//! - Direct codecs bind type-specific encode fns in `prepare` (outside the timer).

use crate::csv_log::CsvLogger;
use crate::data::{self, fidelity, Fixture};
use crate::serializers::{all_serializers, BenchSerializer, StreamMode};
use anyhow::{Context, Result};
use serde_json::Value;
use std::hint::black_box;
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
            fixtures.push(data::make_one(
                &type_id, seed, i, children, points, count, attrs,
            )?);
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

/// Encode one cell into `out` (caller cleared): N=1 → raw codec bytes;
/// N>1 → u32 LE count + (u32 LE len + payload)×N.
/// Matches C `bench_serialize_cell` so DataTypeInstanceCount reflects real batch work.
fn serialize_cell_into(
    ser: &mut dyn BenchSerializer,
    fixtures: &[Fixture],
    out: &mut Vec<u8>,
) -> Result<()> {
    if fixtures.is_empty() {
        anyhow::bail!("empty batch");
    }
    if fixtures.len() == 1 {
        return ser.serialize_into(black_box(&fixtures[0]), out);
    }
    let n = fixtures.len() as u32;
    out.extend_from_slice(&n.to_le_bytes());
    // Per-item scratch reuses capacity across the batch (not the outer `out` frame).
    let mut part = Vec::with_capacity(256);
    for fx in fixtures {
        part.clear();
        ser.serialize_into(black_box(fx), &mut part)?;
        let len = part.len() as u32;
        out.extend_from_slice(&len.to_le_bytes());
        out.extend_from_slice(&part);
    }
    Ok(())
}

fn deserialize_cell_bytes(
    ser: &mut dyn BenchSerializer,
    buf: &[u8],
    expected: &[Fixture],
) -> Result<Vec<Fixture>> {
    if expected.len() == 1 {
        return Ok(vec![ser.deserialize_bytes(black_box(buf))?]);
    }
    if buf.len() < 4 {
        anyhow::bail!("batch frame too short");
    }
    let n = u32::from_le_bytes(buf[0..4].try_into()?) as usize;
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
        out.push(ser.deserialize_bytes(black_box(&buf[o..o + item_len]))?);
        o += item_len;
    }
    Ok(out)
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
        if !fidelity(a, b) {
            anyhow::bail!("fidelity failed for {}", a.name());
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
            // Harness-owned output buffer: capacity reused across reps (issue #59).
            let mut ser_buf = Vec::with_capacity(64 * 1024);
            for mode in mode_list {
                let mut had_error = false;
                for i in 0..repetitions {
                    if had_error {
                        break;
                    }
                    let measured = (|| -> Result<(u128, u128, usize)> {
                        // Batch cells: frame N single-item payloads (same as C harness).
                        // N=1 is a thin passthrough — no framing overhead.
                        ser_buf.clear();
                        let t0 = Instant::now();
                        if mode == "stream" {
                            // Native stream when available; otherwise adapted via serialize_into.
                            if cell.fixtures.len() == 1 {
                                let n = ser.serialize_stream(
                                    black_box(&cell.fixtures[0]),
                                    black_box(&mut ser_buf),
                                )?;
                                let ser_ns = t0.elapsed().as_nanos();
                                black_box(n);
                                let t1 = Instant::now();
                                let outs =
                                    deserialize_cell_bytes(ser.as_mut(), &ser_buf, &cell.fixtures)?;
                                let deser_ns = t1.elapsed().as_nanos();
                                black_box(&outs);
                                check_batch_fidelity(&cell.fixtures, &outs)?;
                                Ok((ser_ns, deser_ns, n))
                            } else {
                                serialize_cell_into(ser.as_mut(), &cell.fixtures, &mut ser_buf)?;
                                let ser_ns = t0.elapsed().as_nanos();
                                black_box(ser_buf.len());
                                let t1 = Instant::now();
                                let outs =
                                    deserialize_cell_bytes(ser.as_mut(), &ser_buf, &cell.fixtures)?;
                                let deser_ns = t1.elapsed().as_nanos();
                                black_box(&outs);
                                check_batch_fidelity(&cell.fixtures, &outs)?;
                                Ok((ser_ns, deser_ns, ser_buf.len()))
                            }
                        } else {
                            serialize_cell_into(ser.as_mut(), &cell.fixtures, &mut ser_buf)?;
                            let ser_ns = t0.elapsed().as_nanos();
                            black_box(ser_buf.len());
                            let t1 = Instant::now();
                            let outs =
                                deserialize_cell_bytes(ser.as_mut(), &ser_buf, &cell.fixtures)?;
                            let deser_ns = t1.elapsed().as_nanos();
                            black_box(&outs);
                            check_batch_fidelity(&cell.fixtures, &outs)?;
                            Ok((ser_ns, deser_ns, ser_buf.len()))
                        }
                    })();
                    match measured {
                        Ok((ser_ns, deser_ns, size)) => {
                            let nk = match ser.native_kind() {
                                crate::serializers::NativeKind::Serde => "serde",
                                crate::serializers::NativeKind::Message => "message",
                                crate::serializers::NativeKind::Archive => "archive",
                                crate::serializers::NativeKind::Direct => "direct",
                            };
                            let sm = match ser.stream_mode() {
                                StreamMode::Native => "native",
                                StreamMode::Adapted => "adapted",
                            };
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
                                nk,
                                sm,
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
