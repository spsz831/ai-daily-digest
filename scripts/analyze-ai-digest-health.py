import argparse
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


TARGET_ERROR_CODES = {"timeout", "http_403"}


def parse_time(value: str | None, fallback_ts: float) -> datetime:
    if value:
        try:
            # Accept 2026-04-08T12:34:56.000Z
            v = value.replace("Z", "+00:00")
            return datetime.fromisoformat(v)
        except Exception:
            pass
    return datetime.fromtimestamp(fallback_ts, tz=timezone.utc)


def load_runs(logs_dir: Path) -> list[dict[str, Any]]:
    runs: list[dict[str, Any]] = []
    for p in sorted(logs_dir.glob("run-*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            run_time = parse_time(data.get("generatedAt"), p.stat().st_mtime)
            entries = data.get("entries") or []
            if isinstance(entries, list):
                runs.append({"path": str(p), "time": run_time, "entries": entries})
        except Exception:
            continue
    runs.sort(key=lambda r: r["time"])
    return runs


def analyze(runs: list[dict[str, Any]], min_consecutive: int) -> dict[str, Any]:
    # source -> timeline (latest at end)
    timeline: dict[str, list[dict[str, Any]]] = {}
    for run in runs:
        t = run["time"].isoformat()
        for e in run["entries"]:
            source = e.get("sourceName")
            if not source:
                continue
            timeline.setdefault(source, []).append(
                {
                    "time": t,
                    "status": e.get("status"),
                    "errorCode": e.get("errorCode"),
                    "errorMessage": e.get("errorMessage", ""),
                    "xmlUrl": e.get("xmlUrl", ""),
                }
            )

    suggested_disable: list[dict[str, Any]] = []
    watch_list: list[dict[str, Any]] = []

    for source, events in timeline.items():
        # count trailing target errors
        consecutive = 0
        last_code = None
        for ev in reversed(events):
            code = ev.get("errorCode")
            if ev.get("status") == "error" and code in TARGET_ERROR_CODES:
                consecutive += 1
                last_code = code
            else:
                break

        if consecutive >= min_consecutive:
            suggested_disable.append(
                {
                    "sourceName": source,
                    "xmlUrl": events[-1].get("xmlUrl", ""),
                    "consecutiveTargetFailures": consecutive,
                    "lastErrorCode": last_code,
                    "lastSeenAt": events[-1].get("time"),
                }
            )
            continue

        # soft watch: recent frequent errors
        recent_errors = [
            ev for ev in events[-min(5, len(events)) :] if ev.get("status") == "error"
        ]
        if len(recent_errors) >= 2:
            watch_list.append(
                {
                    "sourceName": source,
                    "xmlUrl": events[-1].get("xmlUrl", ""),
                    "recentErrorCount": len(recent_errors),
                    "lastErrorCode": recent_errors[-1].get("errorCode"),
                    "lastSeenAt": events[-1].get("time"),
                }
            )

    suggested_disable.sort(key=lambda x: (-x["consecutiveTargetFailures"], x["sourceName"]))
    watch_list.sort(key=lambda x: (-x["recentErrorCount"], x["sourceName"]))

    return {
        "runsAnalyzed": len(runs),
        "sourcesTracked": len(timeline),
        "suggestedDisable": suggested_disable,
        "watchList": watch_list,
    }


def to_markdown(result: dict[str, Any], days: int, min_consecutive: int) -> str:
    lines: list[str] = []
    lines.append("# AI Digest Feed Health Report")
    lines.append("")
    lines.append(f"- Window: last {days} days")
    lines.append(f"- Runs analyzed: {result['runsAnalyzed']}")
    lines.append(f"- Sources tracked: {result['sourcesTracked']}")
    lines.append(
        f"- Disable rule: trailing `timeout/http_403` failures >= {min_consecutive}"
    )
    lines.append("")
    lines.append("## Suggested Disable List")
    lines.append("")
    if not result["suggestedDisable"]:
        lines.append("No source reached disable threshold.")
    else:
        lines.append("| Source | XML URL | Consecutive Failures | Last Error | Last Seen |")
        lines.append("|---|---|---:|---|---|")
        for item in result["suggestedDisable"]:
            lines.append(
                f"| {item['sourceName']} | {item['xmlUrl']} | {item['consecutiveTargetFailures']} | {item['lastErrorCode']} | {item['lastSeenAt']} |"
            )
    lines.append("")
    lines.append("## Watch List")
    lines.append("")
    if not result["watchList"]:
        lines.append("No watch-list source.")
    else:
        lines.append("| Source | XML URL | Recent Error Count | Last Error | Last Seen |")
        lines.append("|---|---|---:|---|---|")
        for item in result["watchList"]:
            lines.append(
                f"| {item['sourceName']} | {item['xmlUrl']} | {item['recentErrorCount']} | {item['lastErrorCode']} | {item['lastSeenAt']} |"
            )
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    script_dir = Path(__file__).resolve().parent
    project_dir = script_dir.parent
    default_logs_dir = project_dir / "reports" / "health"
    default_output_prefix = default_logs_dir / "health-report"

    parser = argparse.ArgumentParser(description="Analyze AI Daily Digest feed health logs.")
    parser.add_argument(
        "--logs-dir",
        default=str(default_logs_dir),
        help="Directory containing run-*.json health logs",
    )
    parser.add_argument("--days", type=int, default=3, help="Analyze recent N days")
    parser.add_argument(
        "--min-consecutive",
        type=int,
        default=2,
        help="Consecutive timeout/403 failures threshold to suggest disable",
    )
    parser.add_argument(
        "--output-prefix",
        default=str(default_output_prefix),
        help="Output file prefix (without extension)",
    )
    args = parser.parse_args()

    logs_dir = Path(args.logs_dir)
    logs_dir.mkdir(parents=True, exist_ok=True)

    all_runs = load_runs(logs_dir)
    cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)
    runs = [r for r in all_runs if r["time"] >= cutoff]

    result = analyze(runs, args.min_consecutive)
    result["windowDays"] = args.days
    result["minConsecutive"] = args.min_consecutive
    result["generatedAt"] = datetime.now(timezone.utc).isoformat()

    out_prefix_str = str(args.output_prefix)
    if out_prefix_str.lower().endswith(".json") or out_prefix_str.lower().endswith(".md"):
        out_prefix_str = str(Path(out_prefix_str).with_suffix(""))
    json_path = Path(out_prefix_str + ".json")
    md_path = Path(out_prefix_str + ".md")
    json_path.parent.mkdir(parents=True, exist_ok=True)

    json_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    md_path.write_text(to_markdown(result, args.days, args.min_consecutive), encoding="utf-8")

    print(f"[health] runs analyzed: {result['runsAnalyzed']}")
    print(f"[health] suggested disable: {len(result['suggestedDisable'])}")
    print(f"[health] watch list: {len(result['watchList'])}")
    print(f"[health] json: {json_path}")
    print(f"[health] md:   {md_path}")


if __name__ == "__main__":
    main()
