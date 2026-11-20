#!/usr/bin/env python3
"""Límites del plan de Claude (sesión 5 h y semanal) para la barra.

Usa el token OAuth de Claude Code (~/.claude/.credentials.json) contra el
mismo endpoint que `/usage`. Es un endpoint interno no documentado: si falla,
se devuelve la última respuesta buena (cache) marcada como `stale`.
"""
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

CACHE_DIR = Path.home() / ".cache" / "quickshell"


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


URL = "https://api.anthropic.com/api/oauth/usage"


def fetch(creds):
    oauth = json.loads(creds.read_text()).get("claudeAiOauth", {})
    req = urllib.request.Request(URL, headers={
        "Authorization": "Bearer " + oauth["accessToken"],
        "anthropic-beta": "oauth-2025-04-20",
        "User-Agent": "quickshell-agent-usage",
    })
    raw = json.load(urllib.request.urlopen(req, timeout=10))

    limits = []
    for lim in raw.get("limits") or []:
        kind = lim.get("kind")
        if kind == "session":
            label = "Sesión (5 h)"
        elif kind == "weekly_all":
            label = "Semanal"
        else:
            model = ((lim.get("scope") or {}).get("model") or {}).get("display_name")
            label = "Semanal · " + model if model else kind
        limits.append({
            "kind": kind,
            "label": label,
            "percent": lim.get("percent") or 0,
            "severity": lim.get("severity") or "normal",
            "resets_at": lim.get("resets_at"),
        })
    return {
        "plan": oauth.get("subscriptionType"),
        "tier": (oauth.get("rateLimitTier") or "").replace("default_claude_", ""),
        "limits": limits,
        "fetched": int(time.time()),
    }


def account_limits(acc):
    cache = CACHE_DIR / f"agent-limits{acc['dir'].name.replace('.claude', '')}.json"
    try:
        out = fetch(acc["dir"] / ".credentials.json")
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(json.dumps(out))
    except (OSError, KeyError, ValueError, urllib.error.URLError) as e:
        err = f"HTTP {e.code}" if isinstance(e, urllib.error.HTTPError) else type(e).__name__
        if err == "HTTP 401":
            err = "token caducado: abre Claude Code con esta cuenta"
        try:
            out = json.loads(cache.read_text())
        except (OSError, ValueError):
            out = {"limits": []}
        out["stale"] = True
        out["error"] = err
    out["email"] = acc["email"]
    out["label"] = acc["label"]
    return out


def main():
    json.dump({"accounts": [account_limits(a) for a in accounts()]}, sys.stdout)


if __name__ == "__main__":
    main()
