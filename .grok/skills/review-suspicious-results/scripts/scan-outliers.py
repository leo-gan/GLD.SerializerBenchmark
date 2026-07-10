#!/usr/bin/env python3
"""Scan latest benchmark stats/CSVs for suspicious size/ops outliers.

Usage:
  python3 scan-outliers.py [--langs c python ...] [--fixture message]
  python3 scan-outliers.py --langs all

Exit 0 always (report tool). Prints human-readable suspects to stdout.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import statistics as st
import sys
from collections import Counter, defaultdict
from pathlib import Path


STEM_RE = re.compile(r"^(\d{4}-\d{2}-\d{2}-\d{6})\.csv$")
DEFAULT_LANGS = ["c", "csharp", "python", "rust", "javascript", "go"]


def repo_root() -> Path:
    here = Path(__file__).resolve()
    for p in here.parents:
        if (p / "config" / "benchmark_config.yaml").is_file():
            return p
    return Path.cwd()


def latest_csv(root: Path, lang: str) -> Path | None:
    d = root / "logs" / lang
    if not d.is_dir():
        return None
    stamps = sorted(
        (m.group(1) for f in d.iterdir() if (m := STEM_RE.match(f.name))),
        reverse=True,
    )
    return d / f"{stamps[0]}.csv" if stamps else None


def load_stats(root: Path, lang: str) -> dict | None:
    for p in (
        root / "reports" / f"stats_{lang}_latest.json",
        root / "dashboard" / "public" / "data" / f"stats_{lang}_latest.json",
        root / "docs" / "dashboard" / "data" / f"stats_{lang}_latest.json",
    ):
        if p.is_file():
            with p.open(encoding="utf-8") as f:
                return json.load(f)
    return None


def flag_group(groups: list[dict], *, size_ratio: float, ops_ratio: float) -> list[tuple]:
    """Return list of (serializer, mode, test_data, n, flags, size, ops)."""
    out = []
    sizes = [g.get("median_size_bytes") or 0 for g in groups if (g.get("median_size_bytes") or 0) > 0]
    opsv = [g.get("avg_ops_per_sec") or 0 for g in groups if (g.get("avg_ops_per_sec") or 0) > 0]
    if not sizes and not opsv:
        return out
    med_s = st.median(sizes) if sizes else 0
    med_o = st.median(opsv) if opsv else 0
    for g in groups:
        ser = g.get("serializer") or "?"
        sz = g.get("median_size_bytes") or 0
        o = g.get("avg_ops_per_sec") or 0
        flags = []
        if sz > 0 and med_s > 0 and sz > med_s * size_ratio:
            flags.append(f"HUGE size {sz:.0f} (med {med_s:.0f})")
        if sz > 0 and med_s > 0 and sz < med_s / size_ratio:
            flags.append(f"TINY size {sz:.0f} (med {med_s:.0f})")
        if 0 < sz <= 3:
            flags.append(f"ABSURD size {sz:.0f}")
        if o > 0 and med_o > 0 and o > med_o * ops_ratio:
            flags.append(f"HIGH ops {o:.0f} (med {med_o:.0f})")
        if o > 0 and med_o > 0 and o < med_o / ops_ratio:
            flags.append(f"LOW ops {o:.0f} (med {med_o:.0f})")
        fid = g.get("mean_fidelity")
        if fid is not None and fid < 0.99:
            flags.append(f"fidelity {fid}")
        if flags:
            out.append(
                (
                    ser,
                    g.get("mode"),
                    g.get("test_data"),
                    g.get("data_type_instance_count"),
                    flags,
                    sz,
                    o,
                )
            )
    return out


def stream_vs_bytes(groups: list[dict]) -> list[str]:
    """Flag serializers where stream and bytes look identical."""
    by_ser: dict[str, dict[str, float]] = defaultdict(dict)
    for g in groups:
        ser = g.get("serializer")
        mode = str(g.get("mode") or "").lower()
        total = g.get("avg_time_total_ns") or g.get("total_median_ns")
        if ser and total and mode:
            by_ser[ser][mode] = float(total)
    msgs = []
    for ser, modes in by_ser.items():
        # normalize
        b = modes.get("bytes") or modes.get("string") or modes.get("buffer")
        s = modes.get("stream")
        if b and s and b > 0:
            rel = abs(b - s) / b
            if rel < 0.05:
                msgs.append(f"{ser}: stream≈bytes (rel diff {rel:.1%}, bytes={b:.0f}ns stream={s:.0f}ns)")
    return msgs


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--langs",
        nargs="*",
        default=None,
        help="Language ids (default: all). Use 'all' for default set.",
    )
    ap.add_argument("--fixture", default="message", help="Primary fixture for TOP/BOT print")
    ap.add_argument("--size-ratio", type=float, default=40.0)
    ap.add_argument("--ops-ratio", type=float, default=25.0)
    args = ap.parse_args()

    root = repo_root()
    langs = args.langs or DEFAULT_LANGS
    if langs == ["all"] or (len(langs) == 1 and langs[0] == "all"):
        langs = DEFAULT_LANGS

    print(f"Repo: {root}")
    print(f"Langs: {langs}")
    print(f"Thresholds: size ×/{args.size_ratio}, ops ×/{args.ops_ratio}")
    print()

    for lang in langs:
        print(f"########## {lang.upper()} ##########")
        stats = load_stats(root, lang)
        csv_path = latest_csv(root, lang)
        if csv_path:
            with csv_path.open(encoding="utf-8", errors="replace") as f:
                rows = list(csv.DictReader(f))
            print(f"  latest CSV: {csv_path.name} rows={len(rows)}")
            if len(rows) < 100:
                print("  WARN: tiny CSV — may be smoke; prefer a full-sized run for conclusions")
            # size<=3 samples
            tiny = [
                r
                for r in rows
                if int(float(r.get("RepetitionIndex") or 0)) > 0
                and float(r.get("Size") or 0) <= 3
            ]
            if tiny:
                c = Counter(
                    (
                        r.get("SerializerName"),
                        r.get("TestDataName"),
                        r.get("DataTypeInstanceCount"),
                        r.get("Size"),
                    )
                    for r in tiny
                )
                print(f"  raw size<=3 samples: {c.most_common(8)}")
            err = csv_path.with_name(csv_path.stem + ".errors.csv")
            if err.is_file() and err.stat().st_size > 50:
                with err.open(encoding="utf-8", errors="replace") as f:
                    er = list(csv.DictReader(f))
                if er:
                    print(
                        f"  errors.csv rows={len(er)}: "
                        f"{Counter(r.get('SerializerName') for r in er).most_common(8)}"
                    )
        else:
            print("  no CSV under logs/")

        if not stats or "groups" not in stats:
            print("  no stats JSON — skip aggregate flags\n")
            continue

        groups = stats["groups"]
        by = defaultdict(list)
        for g in groups:
            by[(g.get("test_data"), g.get("data_type_instance_count"), g.get("mode"))].append(g)

        # Fixture focus TOP/BOT
        for key in sorted(by.keys()):
            td, n, mode = key
            if td != args.fixture or n not in (1, None, "1"):
                continue
            gs = by[key]
            ops = sorted(
                [
                    (
                        g.get("serializer"),
                        g.get("avg_ops_per_sec") or 0,
                        g.get("median_size_bytes") or 0,
                    )
                    for g in gs
                ],
                key=lambda x: -x[1],
            )
            print(f"  {td} n={n} {mode} TOP4: {ops[:4]}")
            print(f"  {td} n={n} {mode} BOT3: {ops[-3:]}")

        suspects = []
        for key, gs in by.items():
            for row in flag_group(gs, size_ratio=args.size_ratio, ops_ratio=args.ops_ratio):
                suspects.append((key, row))

        if suspects:
            print(f"  SUSPECTS ({len(suspects)}):")
            for key, (ser, mode, td, n, flags, sz, o) in suspects[:40]:
                print(f"    {ser} | {td}@n={n} | {mode} | {', '.join(flags)}")
        else:
            print("  SUSPECTS: (none by threshold)")

        # stream vs bytes on preferred fixture n=1
        focus = [
            g
            for g in groups
            if g.get("test_data") == args.fixture
            and g.get("data_type_instance_count") in (1, None, "1")
        ]
        svb = stream_vs_bytes(focus)
        if svb:
            print("  stream≈bytes:")
            for m in svb[:15]:
                print(f"    {m}")
        print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
