#!/usr/bin/env python3
"""Unit tests for scripts/lib/config.sh and the 14 language run-benchmarks.sh scripts."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CONFIG_SH = REPO / "scripts" / "lib" / "config.sh"
RUNNERS = [
    REPO / "c" / "scripts" / "run-benchmarks.sh",
    REPO / "c-sharp" / "scripts" / "run-benchmarks.sh",
    REPO / "cpp" / "scripts" / "run-benchmarks.sh",
    REPO / "fortran" / "scripts" / "run-benchmarks.sh",
    REPO / "go" / "scripts" / "run-benchmarks.sh",
    REPO / "java" / "scripts" / "run-benchmarks.sh",
    REPO / "javascript" / "scripts" / "run-benchmarks.sh",
    REPO / "kotlin" / "scripts" / "run-benchmarks.sh",
    REPO / "mojo" / "scripts" / "run-benchmarks.sh",
    REPO / "php" / "scripts" / "run-benchmarks.sh",
    REPO / "python" / "scripts" / "run-benchmarks.sh",
    REPO / "rust" / "scripts" / "run-benchmarks.sh",
    REPO / "swift" / "scripts" / "run-benchmarks.sh",
    REPO / "zig" / "scripts" / "run-benchmarks.sh",
]


class RunnerConfigTest(unittest.TestCase):
    def test_bash_syntax_all_runners(self) -> None:
        for script in [CONFIG_SH, *RUNNERS]:
            res = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"{script}: {res.stderr}")

    def test_invalid_mode_exits_with_usage(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            for script in RUNNERS:
                res = subprocess.run(
                    ["bash", str(script), "invalid-mode"],
                    env={"HOME": str(Path.home()), "PATH": "/usr/bin:/bin", "LOG_DIR": tmp},
                    capture_output=True,
                    text=True,
                )
                self.assertNotEqual(res.returncode, 0, f"{script} should reject invalid-mode")
                self.assertIn("Usage:", res.stdout + res.stderr)

    def test_bench_init_runner_smoke_and_custom_modes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            res_smoke = subprocess.run(
                [
                    "bash",
                    "-c",
                    f'source "{CONFIG_SH}" && LOG_DIR="{tmp}" bench_init_runner python json smoke && '
                    'printf "%s|%s|%s|%s|%s\n" "$MODE" "$REPS" "$FILTER_SER" "$FILTER_DATA" "${ARGS[*]}"',
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertEqual(res_smoke.stdout.strip().splitlines()[-1], "smoke|2|json|message|2 json message")

            res_custom = subprocess.run(
                [
                    "bash",
                    "-c",
                    f'set -euo pipefail; source "{CONFIG_SH}"; LOG_DIR="{tmp}"; '
                    'bench_init_runner rust serde_json custom 25 rkyv telemetry; '
                    'printf "%s|%s|%s|%s|%s\n" "$MODE" "$REPS" "$FILTER_SER" "$FILTER_DATA" "${ARGS[*]}"',
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertEqual(
                res_custom.stdout.strip().splitlines()[-1],
                "custom|25|rkyv|telemetry|25 rkyv telemetry",
            )

            # Columnar smoke in CI invokes: custom 2 "arrow-ipc,..." with no dataFilter under set -euo pipefail.
            res_columnar = subprocess.run(
                [
                    "bash",
                    "-c",
                    f'set -euo pipefail; source "{CONFIG_SH}"; LOG_DIR="{tmp}"; '
                    f'BENCHMARK_RUN_CONFIG="{REPO}/config/library/columnar-smoke.yaml"; export BENCHMARK_RUN_CONFIG; '
                    'bench_init_runner python json custom 2 "arrow-ipc,parquet,orc"; '
                    'printf "%s|%s|%s|%s|%s\n" "$MODE" "$REPS" "$FILTER_SER" "$FILTER_DATA" "${ARGS[*]}"',
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertEqual(
                res_columnar.stdout.strip().splitlines()[-1],
                "custom|2|arrow-ipc,parquet,orc||2 arrow-ipc,parquet,orc",
            )

            # Unfiltered mode (all-single) with both FILTER_SER and FILTER_DATA empty under set -euo pipefail.
            res_all_single = subprocess.run(
                [
                    "bash",
                    "-c",
                    f'set -euo pipefail; source "{CONFIG_SH}"; LOG_DIR="{tmp}"; '
                    'bench_init_runner go "encoding/json" all-single; '
                    'printf "%s|%s|%s|%s|%s\n" "$MODE" "$REPS" "$FILTER_SER" "$FILTER_DATA" "${ARGS[*]}"',
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertEqual(
                res_all_single.stdout.strip().splitlines()[-1],
                "all-single|10|||10",
            )


if __name__ == "__main__":
    unittest.main()
