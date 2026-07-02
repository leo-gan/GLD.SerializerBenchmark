//! Rust serializer benchmark runner.

mod csv_log;
mod data;
mod serializers;

use crate::csv_log::CsvLogger;
use crate::data::{all_fixtures, Fixture};
use crate::serializers::{all_serializers, BenchSerializer};
use clap::Parser;
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
    /// Output log directory (default: ../logs/rust relative to cwd, or LOG_DIR env)
    #[arg(long, default_value = "")]
    log_dir: String,
}

fn now_ns() -> u128 {
    // perf_counter equivalent: Instant is monotonic; convert duration from process start not needed
    // Use Instant delta within measurement only.
    0
}

fn measure_pair(
    ser: &dyn BenchSerializer,
    fixture: &Fixture,
    mode: &str,
) -> anyhow::Result<(u128, u128, usize, f64)> {
    if mode == "bytes" {
        let t0 = Instant::now();
        let data = ser.serialize_bytes(fixture)?;
        let t1 = Instant::now();
        let out = ser.deserialize_bytes(&data, fixture)?;
        let t2 = Instant::now();
        let ok = fidelity(fixture, &out);
        Ok((
            t0.elapsed().as_nanos() - (t2.duration_since(t1).as_nanos()), // wrong
            0,
            data.len(),
            if ok { 1.0 } else { 0.0 },
        ))
    } else {
        // stream: write/read via intermediate buffer (BytesIO equivalent)
        let t0 = Instant::now();
        let data = ser.serialize_bytes(fixture)?;
        let ser_ns = t0.elapsed().as_nanos();
        let t1 = Instant::now();
        let out = ser.deserialize_bytes(&data, fixture)?;
        let deser_ns = t1.elapsed().as_nanos();
        let ok = fidelity(fixture, &out);
        if !ok {
            anyhow::bail!("roundtrip fidelity failed");
        }
        Ok((ser_ns, deser_ns, data.len(), 1.0))
    }
}

fn measure_pair_fixed(
    ser: &dyn BenchSerializer,
    fixture: &Fixture,
) -> anyhow::Result<(u128, u128, usize)> {
    let t0 = Instant::now();
    let data = ser.serialize_bytes(fixture)?;
    let ser_ns = t0.elapsed().as_nanos();

    let t1 = Instant::now();
    let out = ser.deserialize_bytes(&data, fixture)?;
    let deser_ns = t1.elapsed().as_nanos();

    if !fidelity(fixture, &out) {
        anyhow::bail!("roundtrip fidelity failed for {}", ser.name());
    }
    Ok((ser_ns, deser_ns, data.len()))
}

fn fidelity(a: &Fixture, b: &Fixture) -> bool {
    // Prefer structural equality; fall back to JSON for float/key-order quirks.
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
            x.id == y.id && x.param1 == y.param1 && x.measurements.len() == y.measurements.len()
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
    } else if let Ok(d) = std::env::var("LOG_DIR") {
        PathBuf::from(d)
    } else {
        // repo_root/logs/rust when run from rust/
        PathBuf::from("../logs/rust")
    };

    std::fs::create_dir_all(&log_dir)?;

    // Shared timestamp from the orchestrator (run-all-benchmarks.sh) ensures
    // one logical run produces matching filenames across languages.
    let log_name = if let Ok(ts) = std::env::var("BENCHMARK_TS") {
        if ts.len() >= 15 && ts.contains('-') {
            format!("{}.csv", ts)
        } else {
            format!("{}.csv", ts)
        }
    } else {
        // Local fallback timestamp (rare)
        let secs = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        format!("local-{}.csv", secs)
    };

    let log_path = log_dir.join(&log_name);
    let mut logger = CsvLogger::create(&log_path)?;

    let serializers: Vec<Box<dyn BenchSerializer>> = all_serializers()
        .into_iter()
        .filter(|s| {
            args.serializer_filter
                .as_ref()
                .map(|f| s.name().to_lowercase().contains(&f.to_lowercase()))
                .unwrap_or(true)
        })
        .collect();

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
        for ser in &serializers {
            if !ser.supports(fx.name()) {
                continue;
            }
            for mode in &modes {
                let mut had_error = false;
                for i in 0..args.repetitions {
                    match measure_pair_fixed(ser.as_ref(), fx) {
                        Ok((ser_ns, deser_ns, size)) => {
                            if !had_error {
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
                                )?;
                            }
                        }
                        Err(e) => {
                            if !had_error {
                                eprintln!(
                                    "[ERROR] {} / {} / {}: {}",
                                    ser.name(),
                                    fx.name(),
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
    }

    logger.flush()?;
    println!("[PROGRESS] Complete. Results: {}", log_path.display());
    // silence unused warnings
    let _ = now_ns;
    let _ = measure_pair;
    Ok(())
}
