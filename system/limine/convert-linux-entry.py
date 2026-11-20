#!/usr/bin/env python3
"""Convierte una entrada simple protocol:efi a protocol:linux, conservándola como respaldo."""
import pathlib
import re
import sys

path, target, cmdline = sys.argv[1:]
p = pathlib.Path(path)
lines = p.read_text().splitlines()
start = next((i for i, line in enumerate(lines) if line.rstrip() == "/" + target), None)
if start is None:
    raise SystemExit(f"No existe la entrada /{target} en {p}")
end = next((i for i in range(start + 1, len(lines)) if re.match(r"^/[^/]", lines[i])), len(lines))
body = lines[start + 1:end]
allowed = re.compile(r"^\s+(?:protocol|path|cmdline|comment)\s*:")
unknown = [line for line in body if line.strip() and not allowed.match(line)]
if unknown:
    raise SystemExit("La entrada original tiene opciones no reconocidas; no la modifico: " + " | ".join(unknown))
backup_title = "/Arch Linux (UKI, respaldo)"
if any(line.rstrip() == backup_title for line in lines):
    raise SystemExit("Ya existe la entrada de respaldo UKI; no añado otra")

linux = [
    "/" + target,
    "    //Linux",
    "    protocol: linux",
    "    kernel_path: boot():/vmlinuz-linux",
    "    kernel_cmdline: " + cmdline,
    "    module_path: boot():/initramfs-linux.img",
    "",
    "    //Snapshots",
]
ukibackup = [""] + [backup_title] + body
p.write_text("\n".join(lines[:start] + linux + ukibackup + lines[end:]) + "\n")
