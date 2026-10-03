//! Rust serializer benchmark runner (Data Model v2 only).

mod compress;
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
    /// Serializer filter. No comma: case-insensitive substring.
    /// A comma splits, trims, and keeps case-insensitive exact names only.
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

/// Empty selects every serializer. A filter with no comma keeps substring match.
/// A comma-separated list is case-insensitive exact match, so `parquet` does not
/// select `parquet-uncompressed` and `json` does not select `simd-json`.
pub(crate) fn serializer_selected(name: &str, filter: Option<&str>) -> bool {
    let Some(filter) = filter.map(str::trim).filter(|s| !s.is_empty()) else {
        return true;
    };
    if !filter.contains(',') {
        return name.to_lowercase().contains(&filter.to_lowercase());
    }
    let tokens: Vec<&str> = filter
        .split(',')
        .map(str::trim)
        .filter(|t| !t.is_empty())
        .collect();
    if tokens.is_empty() {
        return true;
    }
    let name_l = name.to_lowercase();
    tokens.iter().any(|t| name_l == t.to_lowercase())
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

#[cfg(test)]
mod tests {
    use super::serializer_selected;
    use crate::serializers::all_serializers;

    #[test]
    fn comma_allow_list_is_exact_names_only() {
        let allow = "arrow-ipc,parquet,parquet-uncompressed,sbe,serde_json,prost,serde_avro_fast";
        let mut selected: Vec<&str> = all_serializers()
            .iter()
            .map(|s| s.name())
            .filter(|n| serializer_selected(n, Some(allow)))
            .collect();
        selected.sort_unstable();
        assert_eq!(
            selected,
            vec![
                "arrow-ipc",
                "parquet",
                "parquet-uncompressed",
                "prost",
                "sbe",
                "serde_avro_fast",
                "serde_json",
            ]
        );

        let mut substr: Vec<&str> = all_serializers()
            .iter()
            .map(|s| s.name())
            .filter(|n| serializer_selected(n, Some("json")))
            .collect();
        substr.sort_unstable();
        // sonic-rs does not contain the substring "json".
        assert_eq!(substr, vec!["serde_json", "simd-json"]);

        let mut exact: Vec<&str> = all_serializers()
            .iter()
            .map(|s| s.name())
            .filter(|n| serializer_selected(n, Some("json,parquet")))
            .collect();
        exact.sort_unstable();
        assert_eq!(exact, vec!["parquet"]);

        assert!(serializer_selected("parquet-uncompressed", Some("parquet")));
        assert!(!serializer_selected("parquet-uncompressed", Some("parquet,")));
        assert!(serializer_selected("sbe", Some("SBE, arrow-ipc")));
        assert!(!serializer_selected("simd-json", Some("serde_json,prost")));
        assert_eq!(
            all_serializers()
                .iter()
                .filter(|s| serializer_selected(s.name(), None))
                .count(),
            22
        );
        assert_eq!(
            all_serializers()
                .iter()
                .filter(|s| serializer_selected(s.name(), Some(" , ")))
                .count(),
            22
        );
    }
}
