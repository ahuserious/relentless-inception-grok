#!/usr/bin/env python3
"""Record a minimal passive lifecycle signal without persisting hook input."""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def main() -> int:
    # Consume the event so a large parent pipe cannot block. Its body may contain
    # prompts or tool arguments, so this defense-in-depth hook never persists it.
    sys.stdin.buffer.read()
    try:
        data_root = Path(
            os.environ.get("GROK_PLUGIN_DATA")
            or Path.home() / ".grok" / "relentless-inception"
        ).expanduser()
        audit_directory = data_root / "audit"
        audit_directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        audit_path = audit_directory / "lifecycle.jsonl"
        record = {
            "event": os.environ.get("GROK_HOOK_EVENT", "unknown"),
            "observed_at": datetime.now(timezone.utc).isoformat(),
            "passive": True,
            "satisfies_gate": False,
        }
        descriptor = os.open(audit_path, os.O_APPEND | os.O_CREAT | os.O_WRONLY, 0o600)
        try:
            os.write(descriptor, (json.dumps(record, sort_keys=True) + "\n").encode("utf-8"))
        finally:
            os.close(descriptor)
    except (OSError, TypeError, ValueError):
        # Grok lifecycle hooks are passive and fail open. The MCP runtime remains
        # the only source of hard gate decisions, even when this signal is lost.
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
