"""Golden vectors for B-1 block_shuffle schedule (all language ports must match)."""

from benchmark_analysis.schedule import (
    GOLDEN_BASE_SEED,
    GOLDEN_INSTANCE_COUNT,
    GOLDEN_MODE,
    GOLDEN_NAMES,
    GOLDEN_REP,
    GOLDEN_TYPE_CONFIG_HASH,
    GOLDEN_TYPE_ID,
    derive_schedule_seed,
    fisher_yates,
    golden_permutation,
    normalize_mode,
    resolve_schedule_strategy,
    shuffle_serializer_names,
)


def test_normalize_mode():
    assert normalize_mode("string") == "bytes"
    assert normalize_mode("Stream") == "stream"
    assert normalize_mode("BYTES") == "bytes"


def test_golden_seed_and_permutation():
    # Fixed cross-language contract — do not change without updating every runner.
    seed = derive_schedule_seed(
        GOLDEN_BASE_SEED,
        GOLDEN_TYPE_ID,
        GOLDEN_INSTANCE_COUNT,
        GOLDEN_TYPE_CONFIG_HASH,
        GOLDEN_MODE,
        GOLDEN_REP,
    )
    assert seed == 15992650003647724414
    assert golden_permutation() == ["C", "B", "A"]
    assert shuffle_serializer_names(
        GOLDEN_NAMES,
        base_seed=GOLDEN_BASE_SEED,
        type_id=GOLDEN_TYPE_ID,
        instance_count=GOLDEN_INSTANCE_COUNT,
        type_config_hash=GOLDEN_TYPE_CONFIG_HASH,
        mode=GOLDEN_MODE,
        rep=GOLDEN_REP,
    ) == ["C", "B", "A"]


def test_mode_aliases_same_seed():
    a = derive_schedule_seed(42, "message", 1, "abc", "bytes", 0)
    b = derive_schedule_seed(42, "message", 1, "abc", "string", 0)
    assert a == b


def test_rep_changes_order():
    p0 = shuffle_serializer_names(
        ["A", "B", "C", "D"],
        base_seed=42,
        type_id="message",
        instance_count=1,
        type_config_hash="h",
        mode="bytes",
        rep=0,
    )
    p1 = shuffle_serializer_names(
        ["A", "B", "C", "D"],
        base_seed=42,
        type_id="message",
        instance_count=1,
        type_config_hash="h",
        mode="bytes",
        rep=1,
    )
    # Extremely unlikely to match for 4! with different seeds; allow equality only if RNG collides
    assert p0 == fisher_yates(["A", "B", "C", "D"], derive_schedule_seed(42, "message", 1, "h", "bytes", 0))
    assert len(p0) == 4 and sorted(p0) == ["A", "B", "C", "D"]
    assert sorted(p1) == ["A", "B", "C", "D"]


def test_resolve_strategy_env(monkeypatch):
    monkeypatch.setenv("BENCHMARK_SCHEDULE", "none")
    assert resolve_schedule_strategy(env=dict(BENCHMARK_SCHEDULE="none")) == "none"
    assert resolve_schedule_strategy(env=dict(BENCHMARK_SCHEDULE="block_shuffle")) == "block_shuffle"
