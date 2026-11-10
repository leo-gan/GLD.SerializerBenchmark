"""The dashboard has one gzip JSON snapshot writer."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from snapshot_io import load_json_gz, write_json_gz


class SnapshotIoTest(unittest.TestCase):
    def test_roundtrip_and_roster_update(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            folder = Path(raw)
            stats = folder / "stats_python_latest.json.gz"
            payload = {
                "groups": [
                    {"serializer": "orjson", "serializer_version": "3.10"},
                    {"serializer": "orjson", "serializer_version": "ignored"},
                ]
            }
            write_json_gz(stats, payload)
            self.assertEqual(load_json_gz(stats)["groups"][0]["serializer"], "orjson")
            self.assertFalse(stats.with_suffix(stats.suffix + ".tmp").exists())
            roster = json.loads((folder / "bench-versions.json").read_text(encoding="utf-8"))
            self.assertEqual(roster["python"]["orjson"], "3.10")

    def test_language_pack_does_not_touch_the_roster(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            folder = Path(raw)
            write_json_gz(folder / "python_latest.json.gz", {"language": "python", "run_id": "1"})
            self.assertFalse((folder / "bench-versions.json").exists())

    def test_non_object_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            path = Path(raw) / "stats_python_latest.json.gz"
            write_json_gz(path, {"groups": []})
            # Overwrite with a JSON list through the same gzip container.
            import gzip

            path.write_bytes(gzip.compress(b"[1]"))
            with self.assertRaises(SystemExit):
                load_json_gz(path)


if __name__ == "__main__":
    unittest.main()
