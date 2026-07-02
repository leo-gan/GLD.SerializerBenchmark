//! Rust serializer benchmark runner (Python-aligned prepare/timed call path).

mod csv_log;
mod data;
mod serializers;

use crate::csv_log::CsvLogger;
use crate::data::{all_fixtures, Fixture};
use crate::serializers::{all_serializers, BenchSerializer, StreamMode};
use clap::Parser;
use std::io::Cursor;
use std::path::PathBuf;
use std::time::Instant;

#[derive(Parser, Debug)]
#[command(name = "serializer-benchmark-rust")]
struct Args {
    /// Number of repetitions per serializer+data+mode
    repetitions: u32,
    /// Optional substring filter for serializer names
    serializer_filter: Option<String>,
    /// Optional substring filter for test data names
    data_filter: Option<String>,
    /// Output log directory (default: monorepo logs/rust, or LOG_DIR/rust)
    #[arg(long, default_value = "")]
    log_dir: String,
}

fn default_log_dir() -> PathBuf {
    if let Ok(d) = std::env::var("LOG_DIR") {
        let p = PathBuf::from(d);
        if p.ends_with("rust") {
            return p;
        }
        return p.join("rust");
    }
    // Walk from CARGO_MANIFEST_DIR to monorepo root
    let manifest = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let repo = manifest
        .parent()
        .filter(|p| p.join("config/benchmark_config.yaml").is_file())
        .map(|p| p.to_path_buf())
        .unwrap_or_else(|| manifest.join(".."));
    repo.join("logs").join("rust")
}

fn measure_bytes(
    ser: &mut dyn BenchSerializer,
    fixture: &Fixture,
) -> anyhow::Result<(u128, u128, usize)> {
    let t0 = Instant::now();
    let data = ser.serialize_bytes(fixture)?;
    let ser_ns = t0.elapsed().as_nanos();

    let t1 = Instant::now();
    let out = ser.deserialize_bytes(&data)?;
    let deser_ns = t1.elapsed().as_nanos();

    if !fidelity(fixture, &out) {
        anyhow::bail!("roundtrip fidelity failed for {}", ser.name());
    }
    Ok((ser_ns, deser_ns, data.len()))
}

fn measure_stream(
    ser: &mut dyn BenchSerializer,
    fixture: &Fixture,
) -> anyhow::Result<(u128, u128, usize)> {
    let mut buf = Cursor::new(Vec::with_capacity(4096));

    let t0 = Instant::now();
    let size = ser.serialize_stream(fixture, &mut buf)?;
    let ser_ns = t0.elapsed().as_nanos();

    buf.set_position(0);
    let t1 = Instant::now();
    let out = ser.deserialize_stream(&mut buf)?;
    let deser_ns = t1.elapsed().as_nanos();

    if !fidelity(fixture, &out) {
        anyhow::bail!("stream roundtrip fidelity failed for {}", ser.name());
    }
    let _ = ser.stream_mode(); // retained for future logging
    Ok((ser_ns, deser_ns, size))
}

fn fidelity(a: &Fixture, b: &Fixture) -> bool {
    if a == b {
        return true;
    }
    match (a, b) {
        (Fixture::Integer(x), Fixture::Integer(y)) => x == y,
        (Fixture::Edi(x), Fixture::Edi(y)) => {
            x.payer_name == y.payer_name
                && x.payee_name == y.payee_name
                && x.claims.len() == y.claims.len()
                && (x.total_actual_amount - y.total_actual_amount).abs() < 1e-6
        }
        (Fixture::Telemetry(x), Fixture::Telemetry(y)) => {
            x.id == y.id
                && x.param1 == y.param1
                && x.measurements.len() == y.measurements.len()
                && x.measurements
                    .iter()
                    .zip(y.measurements.iter())
                    .all(|(a, b)| (a - b).abs() < 1e-9)
        }
        (Fixture::Person(x), Fixture::Person(y)) => {
            // prost maps datetimes through ms; allow date field drift via JSON fallback
            x.first_name == y.first_name
                && x.last_name == y.last_name
                && x.age == y.age
                && x.gender == y.gender
                && x.police_records == y.police_records
                && x.passport.as_ref().map(|p| (&p.number, &p.authority))
                    == y.passport.as_ref().map(|p| (&p.number, &p.authority))
        }
        (Fixture::Simple(x), Fixture::Simple(y)) => {
            x.id == y.id && x.name == y.name && x.is_active == y.is_active
        }
        _ => {
            let ja = serde_json::to_string(a).unwrap_or_default();
            let jb = serde_json::to_string(b).unwrap_or_default();
            ja == jb
        }
    }
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let log_dir = if !args.log_dir.is_empty() {
        PathBuf::from(&args.log_dir)
    } else {
        default_log_dir()
    };

    std::fs::create_dir_all(&log_dir)?;
    eprintln!("[PROGRESS] Writing results under {}", log_dir.display());

    let log_name = if let Ok(ts) = std::env::var("BENCHMARK_TS") {
        format!("{}.csv", ts)
    } else {
        let secs = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        // Prefer ISO-like local stamp for analysis discoverability
        let dt = chrono::Local::now().format("%Y-%m-%d-%H%M%S").to_string();
        let _ = secs;
        format!("{}.csv", dt)
    };

    let log_path = log_dir.join(&log_name);
    let mut logger = CsvLogger::create(&log_path)?;

    // Export for environment capture tools
    if std::env::var_os("BENCHMARK_TS").is_none() {
        if let Some(stem) = log_path.file_stem().and_then(|s| s.to_str()) {
            std::env::set_var("BENCHMARK_TS", stem);
        }
    }

    let mut serializers = all_serializers()
        .into_iter()
        .filter(|s| {
            args.serializer_filter
                .as_ref()
                .map(|f| s.name().to_lowercase().contains(&f.to_lowercase()))
                .unwrap_or(true)
        })
        .collect::<Vec<_>>();

    let fixtures: Vec<Fixture> = all_fixtures(42)
        .into_iter()
        .filter(|fx| {
            args.data_filter
                .as_ref()
                .map(|f| fx.name().to_lowercase().contains(&f.to_lowercase()))
                .unwrap_or(true)
        })
        .collect();

    let modes = ["bytes", "stream"];

    println!(
        "[PROGRESS] Rust benchmark: {} serializers, {} data types, {} reps",
        serializers.len(),
        fixtures.len(),
        args.repetitions
    );

    for fx in &fixtures {
        println!("[PROGRESS] Testing Data: {}", fx.name());
        for ser in &mut serializers {
            if !ser.supports(fx.name()) {
                continue;
            }
            // Untimed prepare (configs, native messages, kind tracking)
            if let Err(e) = ser.prepare(fx) {
                eprintln!("[ERROR] prepare {} / {}: {}", ser.name(), fx.name(), e);
                continue;
            }
            for mode in &modes {
                let mut had_error = false;
                for i in 0..args.repetitions {
                    let measured = if *mode == "bytes" {
                        measure_bytes(ser.as_mut(), fx)
                    } else {
                        measure_stream(ser.as_mut(), fx)
                    };
                    match measured {
                        Ok((ser_ns, deser_ns, size)) => {
                            if !had_error {
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
                                logger.write_row(
                                    mode,
                                    fx.name(),
                                    args.repetitions,
                                    i,
                                    ser.name(),
                                    ser_ns,
                                    deser_ns,
                                    size,
                                    1.0,
                                    ser.version(),
                                    nk,
                                    sm,
                                )?;
                            }
                        }
                        Err(e) => {
                            if !had_error {
                                eprintln!(
                                    "[ERROR] {} / {} / {} (stream={:?}, native={:?}): {}",
                                    ser.name(),
                                    fx.name(),
                                    mode,
                                    ser.stream_mode(),
                                    ser.native_kind(),
                                    e
                                );
                                had_error = true;
                            }
                        }
                    }
                }
            }
        }
    }

    logger.flush()?;
    println!("[PROGRESS] Complete. Results: {}", log_path.display());
    let _ = StreamMode::Adapted;
    Ok(())
}
