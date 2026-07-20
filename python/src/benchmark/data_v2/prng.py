"""Deterministic xorshift64* PRNG (within-language stability; not cross-lang portable).

Nothing-up-my-sleeve constants:
- ``0x9E3779B97F4A7C15`` = floor(2**64 / φ) (golden ratio avalanche / zero-seed fallback)
- ``0x100000001B3`` = FNV-1a 64-bit prime (used in ``mix_seed``)

Suite seed: ``BENCHMARK_SEED`` / master ``reproducibility.random_seed``.
"""

from __future__ import annotations


class XorShift64:
    __slots__ = ("_state",)

    def __init__(self, seed: int) -> None:
        s = seed & 0xFFFFFFFFFFFFFFFF
        if s == 0:
            s = 0x9E3779B97F4A7C15  # floor(2**64 / φ)
        self._state = s

    def next_u64(self) -> int:
        x = self._state
        x ^= (x << 13) & 0xFFFFFFFFFFFFFFFF
        x ^= x >> 7
        x ^= (x << 17) & 0xFFFFFFFFFFFFFFFF
        self._state = x & 0xFFFFFFFFFFFFFFFF
        return self._state

    def next_int(self, lo: int, hi: int) -> int:
        if hi <= lo:
            return lo
        span = hi - lo + 1
        return lo + int(self.next_u64() % span)

    def next_bool(self) -> bool:
        return (self.next_u64() & 1) == 1

    def next_f64(self) -> float:
        # [0, 1)
        return (self.next_u64() >> 11) * (1.0 / (1 << 53))

    def word(self, min_len: int, max_len: int) -> str:
        n = self.next_int(min_len, max_len)
        alphabet = "abcdefghijklmnopqrstuvwxyz"
        return "".join(alphabet[self.next_u64() % 26] for _ in range(n))


def mix_seed(seed: int, type_id: str, instance_index: int) -> int:
    """Derive a stream seed so types/indices do not share one sequence blindly."""
    h = seed & 0xFFFFFFFFFFFFFFFF
    for ch in type_id.encode("utf-8"):
        h = (h ^ ch) * 0x100000001B3 & 0xFFFFFFFFFFFFFFFF
    h ^= (instance_index & 0xFFFFFFFF) * 0x9E3779B97F4A7C15
    h &= 0xFFFFFFFFFFFFFFFF
    return h or 1
