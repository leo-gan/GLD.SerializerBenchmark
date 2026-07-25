"""Deterministic block-shuffle schedule for benchmark runners (B-1).

Normative algorithm — every language benchmark runner must match the golden
vectors in ``tests/test_schedule.py`` (or re-derive the same steps).

Strategy ``block_shuffle`` (default):
  cell (fixed) → prepare all serializers (untimed)
  → mode block → for each rep: Fisher–Yates shuffle serializers → timed trials

Seed for each shuffle:
  key = f"{base_seed}|{type_id}|{instance_count}|{type_config_hash}|{mode}|{rep}"
  mode normalized: string/buffer → bytes; Stream → stream; lowercase
  u64 = first 8 bytes of SHA-256(key) as little-endian
  PRNG = SplitMix64(u64); Fisher–Yates with next_u64() % (i+1)
"""

from __future__ import annotations

import hashlib
import os
from typing import List, Optional, Sequence, TypeVar

T = TypeVar("T")

# Golden vector inputs (must match tests and other language ports)
GOLDEN_BASE_SEED = 42
GOLDEN_TYPE_ID = "message"
GOLDEN_INSTANCE_COUNT = 1
GOLDEN_TYPE_CONFIG_HASH = "abc"
GOLDEN_MODE = "bytes"
GOLDEN_REP = 0
GOLDEN_NAMES = ["A", "B", "C"]


def normalize_mode(mode: str) -> str:
    m = (mode or "").strip().lower()
    if m in ("string", "buffer"):
        return "bytes"
    if m == "stream":
        return "stream"
    return m


def derive_schedule_seed(
    base_seed: int,
    type_id: str,
    instance_count: int,
    type_config_hash: str,
    mode: str,
    rep: int,
) -> int:
    """64-bit seed for Fisher–Yates for one (cell, mode, rep) group."""
    key = (
        f"{int(base_seed)}|{type_id}|{int(instance_count)}|"
        f"{type_config_hash or ''}|{normalize_mode(mode)}|{int(rep)}"
    )
    digest = hashlib.sha256(key.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "little")


class SplitMix64:
    """SplitMix64 PRNG (public-domain algorithm; fixed constants)."""

    __slots__ = ("_state",)

    def __init__(self, seed: int) -> None:
        self._state = int(seed) & 0xFFFFFFFFFFFFFFFF

    def next_u64(self) -> int:
        self._state = (self._state + 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF
        z = self._state
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9 & 0xFFFFFFFFFFFFFFFF
        z = (z ^ (z >> 27)) * 0x94D049BB133111EB & 0xFFFFFFFFFFFFFFFF
        return (z ^ (z >> 31)) & 0xFFFFFFFFFFFFFFFF

    def next_bounded(self, n: int) -> int:
        if n <= 0:
            return 0
        return self.next_u64() % n


def fisher_yates(items: Sequence[T], seed: int) -> List[T]:
    """Return a new list: Fisher–Yates shuffle of *items* with SplitMix64(*seed*)."""
    arr: List[T] = list(items)
    rng = SplitMix64(seed)
    for i in range(len(arr) - 1, 0, -1):
        j = rng.next_bounded(i + 1)
        arr[i], arr[j] = arr[j], arr[i]
    return arr


def shuffle_serializer_names(
    names: Sequence[str],
    *,
    base_seed: int,
    type_id: str,
    instance_count: int,
    type_config_hash: str,
    mode: str,
    rep: int,
) -> List[str]:
    """Shuffle serializer name strings for one (cell, mode, rep)."""
    seed = derive_schedule_seed(
        base_seed, type_id, instance_count, type_config_hash, mode, rep
    )
    return fisher_yates(list(names), seed)


def golden_permutation() -> List[str]:
    """Expected order for the published golden vector (A,B,C @ seed 42…)."""
    return shuffle_serializer_names(
        GOLDEN_NAMES,
        base_seed=GOLDEN_BASE_SEED,
        type_id=GOLDEN_TYPE_ID,
        instance_count=GOLDEN_INSTANCE_COUNT,
        type_config_hash=GOLDEN_TYPE_CONFIG_HASH,
        mode=GOLDEN_MODE,
        rep=GOLDEN_REP,
    )


def resolve_schedule_strategy(
    config_path: Optional[str] = None,
    env: Optional[dict] = None,
) -> str:
    """Return ``block_shuffle`` or ``none``.

    Preference: env ``BENCHMARK_SCHEDULE``, then master config
    ``reproducibility.schedule.strategy``, default ``block_shuffle``.
    """
    env = env if env is not None else os.environ
    raw = (env.get("BENCHMARK_SCHEDULE") or "").strip().lower()
    if raw in ("none", "block_shuffle"):
        return raw
    try:
        from .config_loader import dig, load_master_config

        data = load_master_config(config_path)
        strat = dig(data, "reproducibility.schedule.strategy", "block_shuffle")
        s = str(strat or "block_shuffle").strip().lower()
        if s in ("none", "block_shuffle"):
            return s
    except Exception:
        pass
    return "block_shuffle"


def resolve_record_run_order(
    config_path: Optional[str] = None,
    env: Optional[dict] = None,
) -> bool:
    env = env if env is not None else os.environ
    if (env.get("BENCHMARK_RECORD_RUN_ORDER") or "").strip().lower() in (
        "0",
        "false",
        "no",
    ):
        return False
    try:
        from .config_loader import dig, load_master_config

        data = load_master_config(config_path)
        v = dig(data, "reproducibility.schedule.record_run_order", True)
        return bool(v if v is not None else True)
    except Exception:
        return True
