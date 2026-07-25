#!/usr/bin/env python3
"""Compare BEFORE vs AFTER stats JSON for B-1 block_shuffle (size/fidelity + rank/time Δ)."""
from __future__ import annotations

import argparse
import json
import statistics
from pathlib import Path


def load_groups(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    groups = data.get("groups") or []
    out = {}
    for g in groups:
        key = (
            g.get("language"),
            g.get("serializer"),
            g.get("test_data"),
            g.get("data_type_instance_count"),
            g.get("mode"),
        )
        out[key] = g
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--before-dir", default="reports/b1-before")
    ap.add_argument("--after-dir", default="reports/b1-after")
    ap.add_argument("--out", default="reports/SCHEDULE_B1_BEFORE_AFTER.md")
    args = ap.parse_args()
    before_dir = Path(args.before_dir)
    after_dir = Path(args.after_dir)

    lines = [
        "# B-1 schedule before / after",
        "",
        "BEFORE = legacy fixed / serializer-outer order (archived).",
        "AFTER = `block_shuffle` (mode → rep → shuffled serializers).",
        "",
    ]
    size_issues = []
    big_movers = []

    for bp in sorted(before_dir.glob("stats_*_before.json")):
        lang = bp.name.replace("stats_", "").replace("_before.json", "")
        apath = after_dir / f"stats_{lang}_after.json"
        if not apath.is_file():
            # also accept stats_<lang>_latest.json
            apath = after_dir / f"stats_{lang}_latest.json"
        if not apath.is_file():
            lines.append(f"## {lang}\n\n_Missing AFTER stats at {apath}_\n")
            continue
        b = load_groups(bp)
        a = load_groups(apath)
        common = sorted(set(b) & set(a))
        only_b = len(set(b) - set(a))
        only_a = len(set(a) - set(b))
        pcts = []
        rank_notes = []
        for k in common:
            bg, ag = b[k], a[k]
            bs, asz = bg.get("median_size_bytes") or 0, ag.get("median_size_bytes") or 0
            if bs > 0 and asz > 0 and abs(asz - bs) / bs > 0.05:
                size_issues.append((lang, k, bs, asz))
            bt = bg.get("total_median_ns") or bg.get("avg_time_total_ns") or 0
            at = ag.get("total_median_ns") or ag.get("avg_time_total_ns") or 0
            if bt > 0:
                pct = (at - bt) / bt * 100.0
                pcts.append(pct)
                if abs(pct) >= 15:
                    big_movers.append((lang, k[1], k[2], k[3], k[4], pct, bt, at))

        # top-1 per (test_data, n, mode) rank change
        from collections import defaultdict

        def best(groups, subset_keys):
            by = defaultdict(list)
            for k in subset_keys:
                g = groups[k]
                key = (g.get("test_data"), g.get("data_type_instance_count"), g.get("mode"))
                by[key].append(g)
            tops = {}
            for key, items in by.items():
                best_g = min(items, key=lambda x: x.get("total_median_ns") or x.get("avg_time_total_ns") or 1e99)
                tops[key] = best_g.get("serializer")
            return tops

        tb, ta = best(b, common), best(a, common)
        swaps = [(k, tb[k], ta[k]) for k in tb if k in ta and tb[k] != ta[k]]
        med = statistics.median(pcts) if pcts else 0
        lines.append(f"## {lang}\n")
        lines.append(f"- Common groups: **{len(common)}** (only BEFORE {only_b}, only AFTER {only_a})")
        lines.append(f"- Median total-time Δ (AFTER vs BEFORE): **{med:+.1f}%** across groups")
        lines.append(f"- #1 serializer changes: **{len(swaps)}** (test_data, n, mode)")
        if swaps[:8]:
            lines.append("- Sample rank-1 swaps:")
            for k, old, new in swaps[:8]:
                lines.append(f"  - `{k}`: {old} → {new}")
        lines.append("")

    lines.append("## Size / fidelity invariants\n")
    if not size_issues:
        lines.append("No median size Δ > 5% on common groups.\n")
    else:
        lines.append(f"**{len(size_issues)}** size mismatches (investigate):\n")
        for lang, k, bs, asz in size_issues[:30]:
            lines.append(f"- {lang} {k}: {bs} → {asz}")
        lines.append("")

    lines.append("## Large time movers (|Δ| ≥ 15%)\n")
    big_movers.sort(key=lambda x: -abs(x[5]))
    if not big_movers:
        lines.append("None.\n")
    else:
        lines.append("| lang | serializer | data | n | mode | Δ% | before ns | after ns |")
        lines.append("|------|------------|------|---|------|----|-----------|----------|")
        for row in big_movers[:40]:
            lang, ser, td, n, mode, pct, bt, at = row
            lines.append(f"| {lang} | {ser} | {td} | {n} | {mode} | {pct:+.1f} | {bt:.0f} | {at:.0f} |")
        lines.append("")

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
