//! hdf5-metno on the array data set. Serial file, one float64 dataset.
//! The path API has no core-driver image, so the timed call writes a file and
//! the buffer is that file. grid_window reads a hyperslab.

use super::{ver, BenchSerializer, NativeKind, StreamMode};
use crate::data::{is_array_id, Fixture, Grid};
use anyhow::{bail, Context, Result};
use hdf5_metno::File;
use std::fs;
use std::io::Write;

pub struct Hdf5Metno {
    window: bool,
    nx: usize,
    ny: usize,
    x0: usize,
    y0: usize,
    wx: usize,
    wy: usize,
}

impl Default for Hdf5Metno {
    fn default() -> Self {
        Self {
            window: false,
            nx: 0,
            ny: 0,
            x0: 0,
            y0: 0,
            wx: 0,
            wy: 0,
        }
    }
}

fn values_to_xy(grid: &Grid) -> Vec<f64> {
    let nx = grid.nx as usize;
    let ny = grid.ny as usize;
    let mut xy = vec![0.0; nx * ny];
    for y in 0..ny {
        for x in 0..nx {
            xy[x * ny + y] = grid.values[y * nx + x];
        }
    }
    xy
}

fn xy_to_values(xy: &[f64], nx: usize, ny: usize) -> Vec<f64> {
    let mut values = vec![0.0; nx * ny];
    for y in 0..ny {
        for x in 0..nx {
            values[y * nx + x] = xy[x * ny + y];
        }
    }
    values
}

fn temp_path() -> std::path::PathBuf {
    use std::sync::atomic::{AtomicU64, Ordering};
    static NEXT: AtomicU64 = AtomicU64::new(0);
    let n = NEXT.fetch_add(1, Ordering::Relaxed);
    let mut path = std::env::temp_dir();
    path.push(format!("gld-hdf5-metno-{}-{n}.h5", std::process::id()));
    path
}

impl BenchSerializer for Hdf5Metno {
    fn name(&self) -> &'static str {
        "hdf5-metno"
    }
    fn version(&self) -> &'static str {
        ver("hdf5-metno")
    }
    fn stream_mode(&self) -> StreamMode {
        StreamMode::Adapted
    }
    fn native_kind(&self) -> NativeKind {
        NativeKind::Archive
    }
    fn supports(&self, test_data_name: &str) -> bool {
        is_array_id(test_data_name)
    }

    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        let Fixture::Grid(grid) = fixture else {
            bail!("hdf5-metno expects a grid");
        };
        self.window = grid.read_window;
        self.nx = grid.nx as usize;
        self.ny = grid.ny as usize;
        self.x0 = grid.x0 as usize;
        self.y0 = grid.y0 as usize;
        self.wx = grid.wx as usize;
        self.wy = grid.wy as usize;
        Ok(())
    }

    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        let Fixture::Grid(grid) = fixture else {
            bail!("hdf5-metno expects a grid");
        };
        let xy = values_to_xy(grid);
        let path = temp_path();
        let write = (|| -> Result<()> {
            let file = File::create(&path)?;
            let dataset = file
                .new_dataset_builder()
                .empty::<f64>()
                .shape([grid.nx as usize, grid.ny as usize])
                .create("grid")?;
            dataset.write_raw(&xy)?;
            drop(dataset);
            drop(file);
            let bytes = fs::read(&path)?;
            out.clear();
            out.extend_from_slice(&bytes);
            Ok(())
        })();
        let _ = fs::remove_file(&path);
        write
    }

    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let path = temp_path();
        let decoded = (|| -> Result<Fixture> {
            let mut file = fs::File::create(&path)?;
            file.write_all(data)?;
            file.sync_all()?;
            drop(file);
            let file = File::open(&path)?;
            let dataset = file.dataset("grid")?;
            let (nx, ny, xy) = if self.window {
                let x1 = self.x0 + self.wx;
                let y1 = self.y0 + self.wy;
                let win = dataset.read_slice_2d::<f64, _>((self.x0..x1, self.y0..y1))?;
                let mut flat = vec![0.0; self.wx * self.wy];
                for ix in 0..self.wx {
                    for iy in 0..self.wy {
                        flat[iy * self.wx + ix] = win[[ix, iy]];
                    }
                }
                (self.wx, self.wy, flat)
            } else {
                let raw = dataset.read_raw::<f64>()?;
                (self.nx, self.ny, xy_to_values(&raw, self.nx, self.ny))
            };
            Ok(Fixture::Grid(Grid {
                nx: nx as i32,
                ny: ny as i32,
                values: xy,
                x0: 0,
                y0: 0,
                wx: 0,
                wy: 0,
                read_window: self.window,
            }))
        })();
        let _ = fs::remove_file(&path);
        decoded.context("hdf5-metno read")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::{check_cell_fidelity, make_one, TypeConfig};

    #[test]
    fn grid_and_window_roundtrip() {
        let cfg = TypeConfig::from_value(serde_json::json!({
            "nx": 8,
            "ny": 6,
            "window": {"x0": 1, "y0": 2, "wx": 3, "wy": 2}
        }));
        for type_id in ["grid", "grid_window"] {
            let fx = make_one(type_id, 7, 0, &cfg).unwrap();
            let mut ser = Hdf5Metno::default();
            ser.prepare(&fx).unwrap();
            let bytes = ser.serialize_bytes(&fx).unwrap();
            assert!(bytes.len() > 100, "{}", bytes.len());
            let out = ser.deserialize_bytes(&bytes).unwrap();
            check_cell_fidelity(type_id, &[fx], &[out]).unwrap();
        }
    }
}
