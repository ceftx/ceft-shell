#!/usr/bin/env python3
"""Backend JSON de nmcli para la ventana NetSettings de Quickshell.

  nm.py state             estado general + dispositivos + conexiones
  nm.py show UUID         todas las propiedades de una conexión
  nm.py secrets UUID      contraseñas guardadas de una conexión
  nm.py wifi [rescan]     redes Wi-Fi visibles
  nm.py run ARG...        ejecuta `nmcli ARG...` -> {ok, out, err}
"""
import json
import re
import subprocess
import sys

# Propiedades que no se pueden (o no conviene) editar
READONLY = {"connection.uuid", "connection.type", "connection.timestamp",
            "connection.read-only", "connection.interface-name-match"}
# Hoja (última parte) de las propiedades que guardan secretos
SECRET_RE = re.compile(r"(^|-)(psk|password|secret|secrets|private-key|wep-key\d|pin|preshared-key)$")


def nmcli(*args, secrets=False):
    cmd = ["nmcli", "--colors", "no"] + (["--show-secrets"] if secrets else []) + list(args)
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=60,
                       env={"LC_ALL": "C", "PATH": "/usr/bin:/bin"})
    return p.returncode, p.stdout, p.stderr.strip()


def split_t(line):
    """Divide una línea de `nmcli -t` respetando los ':' escapados como '\\:'."""
    out, cur, esc = [], [], False
    for ch in line:
        if esc:
            cur.append(ch); esc = False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            out.append("".join(cur)); cur = []
        else:
            cur.append(ch)
    out.append("".join(cur))
    return out


def table(fields, *args):
    code, out, err = nmcli("-t", "-f", ",".join(fields), *args)
    if code != 0:
        raise RuntimeError(err or f"nmcli {' '.join(args)} falló")
    rows = []
    for line in out.splitlines():
        if not line:
            continue
        vals = split_t(line)
        rows.append({f.lower().replace("-", "_"): (vals[i] if i < len(vals) else "") for i, f in enumerate(fields)})
    return rows


def keyvals(*args, secrets=False):
    """Salida `clave:valor` (sin escapado) -> lista ordenada de (clave, valor)."""
    code, out, err = nmcli("-t", "-e", "no", *args, secrets=secrets)
    if code != 0:
        raise RuntimeError(err or "nmcli falló")
    pairs = []
    for line in out.splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            pairs.append((k, "" if v == "--" else v))
    return pairs


def device_details(name):
    d = {"ip4": [], "ip6": [], "dns4": [], "dns6": [], "routes4": []}
    for k, v in keyvals("device", "show", name):
        if not v:
            continue
        if k == "GENERAL.HWADDR": d["hwaddr"] = v
        elif k == "GENERAL.MTU": d["mtu"] = v
        elif k == "GENERAL.VENDOR": d["vendor"] = v
        elif k == "GENERAL.PRODUCT": d["product"] = v
        elif k == "GENERAL.DRIVER": d["driver"] = v
        elif k == "GENERAL.STATE": d["state_full"] = v
        elif k == "WIRED-PROPERTIES.CARRIER": d["carrier"] = v
        elif k == "IP4.GATEWAY": d["gw4"] = v
        elif k == "IP6.GATEWAY": d["gw6"] = v
        elif k.startswith("IP4.ADDRESS"): d["ip4"].append(v)
        elif k.startswith("IP6.ADDRESS"): d["ip6"].append(v)
        elif k.startswith("IP4.DNS"): d["dns4"].append(v)
        elif k.startswith("IP6.DNS"): d["dns6"].append(v)
        elif k.startswith("IP4.ROUTE"): d["routes4"].append(v)
    return d


def cmd_state():
    gen = table(["STATE", "CONNECTIVITY", "WIFI-HW", "WIFI", "WWAN-HW", "WWAN"], "general", "status")[0]
    _, host, _ = nmcli("general", "hostname")
    _, net, _ = nmcli("networking")
    devices = table(["DEVICE", "TYPE", "STATE", "CONNECTION", "CON-UUID"], "device", "status")
    for d in devices:
        if d["type"] not in ("loopback",) and not d["device"].startswith("veth"):
            d.update(device_details(d["device"]))
    conns = table(["NAME", "UUID", "TYPE", "DEVICE", "ACTIVE", "STATE", "AUTOCONNECT",
                   "AUTOCONNECT-PRIORITY", "TIMESTAMP-REAL", "FILENAME"], "connection", "show")
    return {"general": {**gen, "hostname": host.strip(), "networking": net.strip()},
            "devices": devices, "connections": conns}


def cmd_show(uuid):
    props = []
    for k, v in keyvals("connection", "show", "uuid", uuid):
        if k.split(".")[0].isupper():      # GENERAL.*, IP4.* = estado en vivo, no editable
            continue
        if SECRET_RE.search(k.rsplit(".", 1)[-1]):
            continue                      # los secretos van por `secrets`
        props.append({"key": k, "value": v, "readonly": k in READONLY})
    return {"uuid": uuid, "props": props}


def cmd_secrets(uuid):
    out = []
    for k, v in keyvals("connection", "show", "uuid", uuid, secrets=True):
        if not k.split(".")[0].isupper() and v and SECRET_RE.search(k.rsplit(".", 1)[-1]):
            out.append({"key": k, "value": v})
    return {"uuid": uuid, "secrets": out}


def cmd_wifi(rescan=False):
    rows = table(["IN-USE", "SSID", "BSSID", "MODE", "CHAN", "FREQ", "RATE", "SIGNAL", "SECURITY", "DEVICE"],
                 "device", "wifi", "list", "--rescan", "yes" if rescan else "no")
    for r in rows:
        r["in_use"] = r["in_use"].strip() == "*"
        r["signal"] = int(r["signal"] or 0)
    return {"networks": rows}


def cmd_run(args):
    code, out, err = nmcli(*args)
    return {"ok": code == 0, "code": code, "out": out.strip(), "err": err}


def main(argv):
    if not argv:
        raise SystemExit(__doc__)
    c, rest = argv[0], argv[1:]
    try:
        if c == "state": res = cmd_state()
        elif c == "show": res = cmd_show(rest[0])
        elif c == "secrets": res = cmd_secrets(rest[0])
        elif c == "wifi": res = cmd_wifi(bool(rest and rest[0] == "rescan"))
        elif c == "run": res = cmd_run(rest)
        else: raise SystemExit(__doc__)
    except (RuntimeError, IndexError, subprocess.TimeoutExpired) as e:
        res = {"ok": False, "err": str(e) or "argumentos inválidos"}
    print(json.dumps(res, ensure_ascii=False))


if __name__ == "__main__":
    main(sys.argv[1:])
