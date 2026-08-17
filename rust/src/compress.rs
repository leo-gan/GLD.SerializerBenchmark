//! One-shot gzip(6) / zstd(3) of already-written bytes (not timed).

use flate2::write::GzEncoder;
use flate2::Compression;
use std::io::Write;

/// Returns `(gzip_len, zstd_len)`. Either value is 0 on an empty input or codec error.
pub fn compress_sizes(raw: &[u8]) -> (usize, usize) {
    if raw.is_empty() {
        return (0, 0);
    }
    let mut enc = GzEncoder::new(Vec::new(), Compression::new(6));
    let gz = if enc.write_all(raw).is_ok() {
        enc.finish().map(|v| v.len()).unwrap_or(0)
    } else {
        0
    };
    let zs = zstd::encode_all(raw, 3).map(|v| v.len()).unwrap_or(0);
    (gz, zs)
}

#[cfg(test)]
mod tests {
    use super::compress_sizes;

    #[test]
    fn gzip_hello_is_about_25() {
        let (gz, zs) = compress_sizes(b"hello");
        assert!((20..=40).contains(&gz), "gzip={gz}");
        assert!(zs > 0, "zstd should be available");
    }

    #[test]
    fn empty_is_zero() {
        assert_eq!(compress_sizes(b""), (0, 0));
    }
}
