"""Per-source request ledger, shared by all transports.

Free RapidAPI tiers are per calendar month and per hub product; a source
that silently blows its quota dies for the whole month. Every adapter is
expected to call ``budget.record(name)`` per request and refuse to start a
run once ``over_budget(name, limit)`` is true (limit = 80% of the tier by
convention, so a run never dies mid-quota).

The ledger is a plain JSON file (``ingest/budget.json``) so it survives
processes and is diff-able by eye:

    {"walmart_rapidapi": {"2026-09": 120}}
"""
from __future__ import annotations

import json
import time
from pathlib import Path

DEFAULT_PATH = Path(__file__).with_name("budget.json")


def _month() -> str:
    return time.strftime("%Y-%m")


def _load(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text() or "{}")


def used(source: str, path: Path = DEFAULT_PATH) -> int:
    """Requests already charged to ``source`` in the current calendar month."""
    return _load(path).get(source, {}).get(_month(), 0)


def record(source: str, n: int = 1, path: Path = DEFAULT_PATH) -> int:
    """Charge ``n`` requests against the source; returns the new count."""
    ledger = _load(path)
    month = ledger.setdefault(source, {})
    month[_month()] = month.get(_month(), 0) + n
    path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n")
    return month[_month()]


def over_budget(source: str, limit: int, path: Path = DEFAULT_PATH) -> bool:
    """True once the source has met or exceeded ``limit`` this month."""
    return used(source, path) >= limit
