"""Per-case extras for schema-driven formats (not suite data types)."""

from __future__ import annotations

from contextvars import ContextVar
from typing import Any

current_schema: ContextVar[Any] = ContextVar("current_schema", default=None)
