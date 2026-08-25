//! CSV output matching the project schema (nanoseconds, Language=rust).

use std::fs::{create_dir_all, File};
use std::io::{BufWriter, Write};
use std::path::Path;

pub struct CsvLogger {
    writer: BufWriter<File>,
}

impl CsvLogger {
    pub fn create(path: &Path) -> std::io::Result<Self> {
        if let Some(parent) = path.parent() {
            create_dir_all(parent)?;
        }
        let file = File::create(path)?;
        let mut writer = BufWriter::new(file);
        // SerializerVersion immediately follows SerializerName.
        // RunOrder / SchedulePosition optional (empty when not recording).
        writeln!(
            writer,
            "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,NativeKind,StreamMode,DataTypeInstanceCount,TypeConfigHash,RunOrder,SchedulePosition,SizeGzip,SizeZstd"
        )?;
        Ok(Self { writer })
    }

    pub fn write_row(
        &mut self,
        mode: &str,
        test_data: &str,
        repetitions: u32,
        rep_index: u32,
        serializer: &str,
        time_ser_ns: u128,
        time_deser_ns: u128,
        size: usize,
        fidelity: f64,
        version: &str,
        native_kind: &str,
        stream_mode: &str,
    ) -> std::io::Result<()> {
        let total = time_ser_ns + time_deser_ns;
        let ops_ser = if time_ser_ns > 0 {
            1_000_000_000.0 / time_ser_ns as f64
        } else {
            0.0
        };
        let ops_deser = if time_deser_ns > 0 {
            1_000_000_000.0 / time_deser_ns as f64
        } else {
            0.0
        };
        let ops_tot = if total > 0 {
            1_000_000_000.0 / total as f64
        } else {
            0.0
        };
        writeln!(
            self.writer,
            "rust,{mode},{test_data},{repetitions},{rep_index},{serializer},{version},{time_ser_ns},{time_deser_ns},{size},{total},{ops_ser:.6},{ops_deser:.6},{ops_tot:.6},0,{fidelity:.1},{native_kind},{stream_mode},,,,,,"
        )
    }

    /// Write a v2 row. `run_order` / `schedule_position` are `Some` when recording, else empty columns.
    pub fn write_row_v2(
        &mut self,
        mode: &str,
        test_data: &str,
        repetitions: u32,
        rep_index: u32,
        serializer: &str,
        time_ser_ns: u128,
        time_deser_ns: u128,
        size: usize,
        fidelity: f64,
        version: &str,
        native_kind: &str,
        stream_mode: &str,
        instance_count: u32,
        type_config_hash: &str,
        run_order: Option<i32>,
        schedule_position: Option<i32>,
        size_gzip: usize,
        size_zstd: usize,
    ) -> std::io::Result<()> {
        let total = time_ser_ns + time_deser_ns;
        let ops_ser = if time_ser_ns > 0 {
            1e9 / time_ser_ns as f64
        } else {
            0.0
        };
        let ops_deser = if time_deser_ns > 0 {
            1e9 / time_deser_ns as f64
        } else {
            0.0
        };
        let ops_tot = if total > 0 {
            1e9 / total as f64
        } else {
            0.0
        };
        let ro = run_order
            .map(|v| v.to_string())
            .unwrap_or_default();
        let sp = schedule_position
            .map(|v| v.to_string())
            .unwrap_or_default();
        let gz = if size_gzip > 0 {
            size_gzip.to_string()
        } else {
            String::new()
        };
        let zs = if size_zstd > 0 {
            size_zstd.to_string()
        } else {
            String::new()
        };
        writeln!(
            self.writer,
            "rust,{mode},{test_data},{repetitions},{rep_index},{serializer},{version},{time_ser_ns},{time_deser_ns},{size},{total},{ops_ser:.6},{ops_deser:.6},{ops_tot:.6},0,{fidelity:.1},{native_kind},{stream_mode},{instance_count},{type_config_hash},{ro},{sp},{gz},{zs}"
        )
    }

    pub fn flush(&mut self) -> std::io::Result<()> {
        self.writer.flush()
    }
}
