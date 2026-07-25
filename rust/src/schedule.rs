//! B-1 deterministic block_shuffle schedule (must match analysis golden vector).
//!
//! Normative algorithm:
//! ```text
//! key = f"{base_seed}|{type_id}|{instance_count}|{type_config_hash}|{mode}|{rep}"
//! mode: string/buffer → bytes; Stream → stream; lowercase
//! u64 = first 8 bytes SHA-256(key) little-endian
//! SplitMix64(u64); Fisher-Yates: for i=n-1..1: j = next_u64() % (i+1); swap
//! ```
//! Golden: names A,B,C seed 42 type message n=1 hash abc mode bytes rep 0 → C,B,A
//! seed value must be 15992650003647724414

use sha2::{Digest, Sha256};
use std::env;

/// Normalize IO mode for schedule keying (cross-language contract).
pub fn normalize_mode(mode: &str) -> String {
    let m = mode.trim().to_ascii_lowercase();
    match m.as_str() {
        "string" | "buffer" => "bytes".to_string(),
        "stream" => "stream".to_string(),
        other => other.to_string(),
    }
}

/// 64-bit seed for Fisher–Yates for one (cell, mode, rep) group.
pub fn derive_schedule_seed(
    base_seed: u64,
    type_id: &str,
    instance_count: i32,
    type_config_hash: &str,
    mode: &str,
    rep: u32,
) -> u64 {
    let mode_n = normalize_mode(mode);
    let key = format!(
        "{}|{}|{}|{}|{}|{}",
        base_seed, type_id, instance_count, type_config_hash, mode_n, rep
    );
    let digest = Sha256::digest(key.as_bytes());
    u64::from_le_bytes(digest[..8].try_into().unwrap())
}

/// SplitMix64 PRNG (public-domain algorithm; fixed constants).
struct SplitMix64 {
    state: u64,
}

impl SplitMix64 {
    fn new(seed: u64) -> Self {
        Self { state: seed }
    }

    fn next_u64(&mut self) -> u64 {
        self.state = self.state.wrapping_add(0x9E3779B97F4A7C15);
        let mut z = self.state;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
        z ^ (z >> 31)
    }
}

/// Return a new list: Fisher–Yates shuffle of `items` with SplitMix64(`seed`).
pub fn fisher_yates<T: Clone>(items: &[T], seed: u64) -> Vec<T> {
    let mut arr = items.to_vec();
    let mut rng = SplitMix64::new(seed);
    let n = arr.len();
    if n < 2 {
        return arr;
    }
    for i in (1..n).rev() {
        let j = (rng.next_u64() % (i as u64 + 1)) as usize;
        arr.swap(i, j);
    }
    arr
}

/// `BENCHMARK_SCHEDULE`: `none` | `block_shuffle` (default `block_shuffle`).
pub fn resolve_schedule_strategy() -> String {
    match env::var("BENCHMARK_SCHEDULE") {
        Ok(v) => {
            let s = v.trim().to_ascii_lowercase();
            if s == "none" || s == "block_shuffle" {
                s
            } else {
                "block_shuffle".into()
            }
        }
        Err(_) => "block_shuffle".into(),
    }
}

/// `BENCHMARK_RECORD_RUN_ORDER`: default true; `0`/`false`/`no` disables.
pub fn resolve_record_run_order() -> bool {
    match env::var("BENCHMARK_RECORD_RUN_ORDER") {
        Ok(v) => {
            let s = v.trim().to_ascii_lowercase();
            !(s == "0" || s == "false" || s == "no")
        }
        Err(_) => true,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn golden_seed_and_permutation() {
        let seed = derive_schedule_seed(42, "message", 1, "abc", "bytes", 0);
        assert_eq!(
            seed, 15992650003647724414u64,
            "golden schedule seed mismatch"
        );
        let p = fisher_yates(&["A", "B", "C"], seed);
        assert_eq!(p, vec!["C", "B", "A"]);
    }

    #[test]
    fn mode_aliases_same_seed() {
        let a = derive_schedule_seed(42, "message", 1, "abc", "bytes", 0);
        let b = derive_schedule_seed(42, "message", 1, "abc", "string", 0);
        let c = derive_schedule_seed(42, "message", 1, "abc", "buffer", 0);
        assert_eq!(a, b);
        assert_eq!(a, c);
    }

    #[test]
    fn normalize_stream_case() {
        assert_eq!(normalize_mode("Stream"), "stream");
        assert_eq!(normalize_mode("BYTES"), "bytes");
    }
}
