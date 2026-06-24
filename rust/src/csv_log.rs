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
        writeln!(
            writer,
            "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,SerializerVersion"
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
            "rust,{mode},{test_data},{repetitions},{rep_index},{serializer},{time_ser_ns},{time_deser_ns},{size},{total},{ops_ser:.6},{ops_deser:.6},{ops_tot:.6},0,{fidelity:.1},{version}"
        )
    }

    pub fn flush(&mut self) -> std::io::Result<()> {
        self.writer.flush()
    }
}
