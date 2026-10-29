"""Write the installed gld-kiln 0.2.0 score for the Kiln wire v2 catalog."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kiln_score_python import score_document

ROOT = Path(__file__).resolve().parents[2]
corpus = json.loads((ROOT / "compliance" / "data" / "kiln" / "v2.json").read_text())
doc = score_document(corpus)
dest = Path("/tmp/kiln-scores/python.json")
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(json.dumps(doc))
print(
    f"version={doc['serializer_version']} pass={doc['passed']} "
    f"fail={doc['failed']} stricter_fail={doc['stricter_failed']}"
)
for case in doc["cases"]:
    if case["outcome"] != "pass" or case.get("stricter"):
        print(case["id"], case["outcome"], case["observed"], case["detail"])
if doc["failed"]:
    sys.exit(1)
