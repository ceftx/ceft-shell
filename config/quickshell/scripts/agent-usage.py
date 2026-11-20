#!/usr/bin/env python3
"""Resumen de tokens de Claude Code a partir de los transcripts locales.

Lee <cuenta>/projects/**/*.jsonl de cada cuenta (incluye subagentes), deduplica por
message.id + requestId (cada bloque de contenido repite el mismo `usage`)
y emite JSON para la barra de Quickshell.
"""
import json
import sys
import time
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

DAYS = 7
ROOT = Path.home() / ".claude" / "projects"


def accounts():
    """Cuentas de Claude Code: ~/.claude (config en ~/.claude.json) y cualquier
    ~/.claude-<nombre> creado con CLAUDE_CONFIG_DIR (config en <dir>/.claude.json)."""
    home = Path.home()
    dirs = [(home / ".claude", home / ".claude.json")]
    dirs += [(d, d / ".claude.json") for d in sorted(home.glob(".claude-*")) if d.is_dir()]
    out = []
    for d, cfg in dirs:
        if not (d / ".credentials.json").exists():
            continue
        try:
            email = (json.loads(cfg.read_text()).get("oauthAccount") or {}).get("emailAddress")
        except (OSError, ValueError):
            email = None
        email = email or d.name
        label = email.split("@")[-1].split(".")[0] if "@" in email else d.name.lstrip(".")
        out.append({"dir": d, "email": email, "label": label})
    return out


def stats(root):
    today = date.today()
    first = today - timedelta(days=DAYS - 1)
    cutoff = time.mktime(first.timetuple())

    seen = set()
    per_day = defaultdict(int)
    t = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
    models = defaultdict(int)
    session_details = defaultdict(lambda: {"tokens": 0, "project": "", "sessionId": ""})
    sessions = set()

    for f in root.rglob("*.jsonl"):
        try:
            if f.stat().st_mtime < cutoff:
                continue
            fh = f.open(encoding="utf-8", errors="replace")
        except OSError:
            continue
        with fh:
            for line in fh:
                if '"usage"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                msg = d.get("message")
                if d.get("type") != "assistant" or not isinstance(msg, dict):
                    continue
                u = msg.get("usage") or {}
                key = (msg.get("id"), d.get("requestId"))
                if key in seen:
                    continue
                seen.add(key)
                try:
                    ts = datetime.fromisoformat(d["timestamp"].replace("Z", "+00:00"))
                except (KeyError, ValueError):
                    continue
                day = ts.astimezone().date()
                if day < first:
                    continue
                inp = u.get("input_tokens", 0) or 0
                out = u.get("output_tokens", 0) or 0
                cr = u.get("cache_read_input_tokens", 0) or 0
                cw = u.get("cache_creation_input_tokens", 0) or 0
                total = inp + out + cr + cw
                per_day[day] += total
                if day == today:
                    t["input"] += inp
                    t["output"] += out
                    t["cache_read"] += cr
                    t["cache_write"] += cw
                    models[msg.get("model") or "?"] += total
                    if d.get("sessionId"):
                        sid = d.get("sessionId")
                        sessions.add(sid)
                        proj = f.parent.name
                        if proj == "subagents":
                            proj = f.parent.parent.name
                        session_details[sid]["tokens"] += total
                        session_details[sid]["project"] = proj
                        session_details[sid]["sessionId"] = sid

    days = [first + timedelta(days=i) for i in range(DAYS)]
    return {
        "today": dict(t, total=sum(t.values())),
        "models": sorted(([m, n] for m, n in models.items()), key=lambda x: -x[1]),
        "sessions": len(sessions),
        "session_details": [{"sessionId": k, "project": v["project"], "tokens": v["tokens"]} for k, v in session_details.items()],
        "days": [["LMXJVSD"[d.weekday()], per_day[d]] for d in days],
        "week": sum(per_day.values()),
    }


def main():
    out = []
    for a in accounts():
        out.append(dict(stats(a["dir"] / "projects"), email=a["email"], label=a["label"], updated=datetime.now().strftime("%H:%M")))
    json.dump({"accounts": out, "updated": datetime.now().strftime("%H:%M")}, sys.stdout)


if __name__ == "__main__":
    main()
