#!/usr/bin/env bash
# Collect rtk gain stats as a single JSON blob for the bar widget.
# Keep command output in files so arbitrary command text cannot break JSON assembly.
set -u

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

summary_status=0
rtk gain --all --format json >"$tmp_dir/summary.json" 2>"$tmp_dir/summary.err" || summary_status=$?

failures_status=0
rtk gain --failures >"$tmp_dir/failures.txt" 2>"$tmp_dir/failures.err" || failures_status=$?

quota_status=0
rtk gain --quota >"$tmp_dir/quota.txt" 2>"$tmp_dir/quota.err" || quota_status=$?

commands_status=0
rtk gain >"$tmp_dir/commands.txt" 2>"$tmp_dir/commands.err" || commands_status=$?

python3 - "$tmp_dir" "$summary_status" "$failures_status" "$quota_status" "$commands_status" <<'PY'
import json
import re
import sys
from pathlib import Path

tmp_dir = Path(sys.argv[1])
statuses = [int(value) for value in sys.argv[2:]]

def read_json(name):
    try:
        return json.loads((tmp_dir / name).read_text())
    except (OSError, json.JSONDecodeError):
        return None

summary = read_json("summary.json")

if statuses[0] != 0 or not isinstance(summary, dict) or "summary" not in summary:
    error = (tmp_dir / "summary.err").read_text().strip()
    print(json.dumps({"error": error or "rtk gain failed", "summary": {}, "daily": [], "weekly": [], "monthly": [], "top_commands": []}))
    raise SystemExit(0)

commands = []
if statuses[3] == 0:
    in_table = False
    for line in (tmp_dir / "commands.txt").read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith("#") and "Command" in stripped and "Count" in stripped:
            in_table = True
            continue
        if in_table and not stripped:
            break
        if in_table and stripped.startswith("─"):
            continue
        if in_table:
            match = re.match(
                r"\s*(\d+)\.\s+(.+?)\s{2,}(\d+)\s+(\d+)\s+(\d+\.\d+)%\s+(\S+)\s+(.+)",
                stripped,
            )
            if match:
                commands.append({
                    "rank": int(match.group(1)),
                    "command": match.group(2).strip(),
                    "count": int(match.group(3)),
                    "saved": int(match.group(4)),
                    "avg_pct": float(match.group(5)),
                    "time": match.group(6),
                    "impact": match.group(7).strip(),
                })

result = dict(summary)
result["daily"] = summary.get("daily", [])
result["weekly"] = summary.get("weekly", [])
result["monthly"] = summary.get("monthly", [])
result["top_commands"] = commands

failures_text = (tmp_dir / "failures.txt").read_text() if statuses[1] == 0 else ""
failure_count = re.search(r"Total failures:\s+(\d+)", failures_text)
recovery_rate = re.search(r"Recovery rate:\s+([\d.]+)%", failures_text)
result["failures"] = {
    "total": int(failure_count.group(1)) if failure_count else 0,
    "recovery_pct": float(recovery_rate.group(1)) if recovery_rate else 0,
}

quota_text = (tmp_dir / "quota.txt").read_text() if statuses[2] == 0 else ""
quota = re.search(r"Estimated monthly quota:\s+(.+)", quota_text)
preserved = re.search(r"Quota preserved:\s+(.+)%", quota_text)
result["quota"] = {
    "estimated_monthly": quota.group(1).strip() if quota else "—",
    "preserved_pct": float(preserved.group(1)) if preserved else 0,
}
print(json.dumps(result))
PY
