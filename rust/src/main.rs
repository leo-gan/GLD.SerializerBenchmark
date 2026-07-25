//! Rust serializer benchmark runner (Data Model v2 only).

mod csv_log;
mod data;
mod run_v2;
mod schedule;
mod serializers;

use clap::Parser;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "serializer-benchmark-rust")]
struct Args {
    /// Number of repetitions per serializer+data+mode
    repetitions: u32,
    /// Optional substring filter for serializer names
    serializer_filter: Option<String>,
    /// Optional substring filter for test data names (type_id)
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

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let log_dir = if !args.log_dir.is_empty() {
        PathBuf::from(&args.log_dir)
    } else {
        default_log_dir()
    };
    std::fs::create_dir_all(&log_dir)?;
    let log_name = if let Ok(ts) = std::env::var("BENCHMARK_TS") {
        format!("{}.csv", ts)
    } else {
        format!("{}.csv", chrono::Local::now().format("%Y-%m-%d-%H%M%S"))
    };
    let log_path = log_dir.join(log_name);
    if std::env::var_os("BENCHMARK_TS").is_none() {
        if let Some(stem) = log_path.file_stem().and_then(|s| s.to_str()) {
            std::env::set_var("BENCHMARK_TS", stem);
        }
    }
    run_v2::run_v2(
        args.repetitions,
        &log_path,
        args.serializer_filter.as_deref(),
        args.data_filter.as_deref(),
    )
}
