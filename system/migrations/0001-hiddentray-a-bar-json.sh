#!/usr/bin/env bash
# Mueve widgets.json bar.hiddenTray -> bar.json tray.hidden (la barra ya lee tray.hidden primero).
# touches: config/ceft-shell/widgets.json
# touches: config/ceft-shell/bar.json
# Idempotente. Si bar.json ya define tray.hidden, gana bar.json y solo se limpia widgets.json.
# Env: CEFT_CONFIG_DIR (dir con widgets.json y bar.json), DRY_RUN=1.
set -euo pipefail
DIR="${CEFT_CONFIG_DIR:?falta CEFT_CONFIG_DIR}"
exec python3 -I - "$DIR" "${DRY_RUN:-}" <<'PY'
import json, os, sys, tempfile
d, dry = sys.argv[1], bool(sys.argv[2])
wf, bf = os.path.join(d, "widgets.json"), os.path.join(d, "bar.json")

def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)

def save(p, data):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.realpath(p)), prefix=".mig-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False); f.write("\n")
    os.replace(tmp, os.path.realpath(p))

if not os.path.isfile(wf):
    print("sin widgets.json: nada que migrar"); sys.exit(0)
w = load(wf)
bar = w.get("bar")
if not isinstance(bar, dict) or "hiddenTray" not in bar:
    print("widgets.json no tiene bar.hiddenTray: nada que migrar"); sys.exit(0)

hidden = bar["hiddenTray"]
b = load(bf) if os.path.isfile(bf) else {}
tray = b.get("tray") if isinstance(b.get("tray"), dict) else {}
if isinstance(tray.get("hidden"), list):
    print("bar.json ya define tray.hidden: se conserva; se quita hiddenTray de widgets.json")
else:
    tray["hidden"] = hidden if isinstance(hidden, list) else []
    b["tray"] = tray
    print(f"bar.json tray.hidden = {json.dumps(tray['hidden'], ensure_ascii=False)}")
    if not dry: save(bf, b)
del bar["hiddenTray"]
if not bar: del w["bar"]
print("widgets.json: bar.hiddenTray eliminado")
if not dry: save(wf, w)
PY
