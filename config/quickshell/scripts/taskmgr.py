#!/usr/bin/env python3
"""Recolector del administrador de tareas: una línea JSON por tick (stdout). Uso: taskmgr.py [intervalo_s]"""
import json
import os
import shutil
import subprocess
import sys
import time

import psutil

INTERVAL = float(sys.argv[1]) if len(sys.argv) > 1 else 1.5
NCPU = psutil.cpu_count() or 1
ME = os.getuid()

gpu_cache = {"t": 0, "v": None}


def gpu():
    if not shutil.which("nvidia-smi"):
        return None
    now = time.time()
    if now - gpu_cache["t"] < 3:
        return gpu_cache["v"]
    gpu_cache["t"] = now
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw",
             "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=2).stdout.strip().splitlines()[0]
        n, u, mu, mt, t, p = [x.strip() for x in out.split(",")]
        gpu_cache["v"] = {"name": n, "util": float(u), "memUsed": float(mu) * 1048576, "memTotal": float(mt) * 1048576,
                          "temp": float(t), "power": float(p) if p.replace(".", "").isdigit() else 0}
    except Exception:
        gpu_cache["v"] = None
    return gpu_cache["v"]


def cpu_name():
    try:
        for line in open("/proc/cpuinfo"):
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return "CPU"


CPU_NAME = cpu_name()
prev_disk = psutil.disk_io_counters()
prev_net = psutil.net_io_counters()
prev_t = time.time()
psutil.cpu_percent(percpu=True)
for p in psutil.process_iter():
    try:
        p.cpu_percent(None)
    except psutil.Error:
        pass
time.sleep(0.3)

while True:
    t0 = time.time()
    dt = max(0.001, t0 - prev_t)
    prev_t = t0
    procs = []
    for p in psutil.process_iter(["pid", "ppid", "name", "username", "memory_info", "status", "num_threads", "cmdline", "uids", "nice"]):
        try:
            i = p.info
            cmd = i["cmdline"] or []
            name = i["name"] or "?"
            if len(name) >= 15 and cmd:
                base = os.path.basename(cmd[0].split(" ")[0])
                if base.startswith(name):
                    name = base
            mem = i["memory_info"]
            procs.append({
                "pid": i["pid"], "ppid": i["ppid"], "name": name, "user": i["username"] or "?",
                "cpu": round(p.cpu_percent(None) / NCPU, 1), "mem": mem.rss if mem else 0,
                "state": i["status"], "threads": i["num_threads"], "mine": bool(i["uids"] and i["uids"].real == ME),
                "nice": i["nice"], "cmd": " ".join(cmd)[:300],
            })
        except (psutil.Error, OSError):
            continue
    vm, sw = psutil.virtual_memory(), psutil.swap_memory()
    disk, net = psutil.disk_io_counters(), psutil.net_io_counters()
    d_r = (disk.read_bytes - prev_disk.read_bytes) / dt if disk and prev_disk else 0
    d_w = (disk.write_bytes - prev_disk.write_bytes) / dt if disk and prev_disk else 0
    n_rx = (net.bytes_recv - prev_net.bytes_recv) / dt
    n_tx = (net.bytes_sent - prev_net.bytes_sent) / dt
    prev_disk, prev_net = disk, net
    freq = psutil.cpu_freq()
    try:
        temps = psutil.sensors_temperatures()
        ct = next((v[0].current for k, v in temps.items() if k in ("k10temp", "coretemp", "zenpower") and v), None)
    except Exception:
        ct = None
    try:
        fs = psutil.disk_usage("/")
        root = {"used": fs.used, "total": fs.total}
    except OSError:
        root = {"used": 0, "total": 0}
    try:
        print(json.dumps({
            "cpu": {"total": psutil.cpu_percent(), "cores": psutil.cpu_percent(percpu=True), "name": CPU_NAME, "n": NCPU,
                    "freq": freq.current if freq else 0, "temp": ct, "load": list(os.getloadavg())},
            "mem": {"total": vm.total, "used": vm.total - vm.available, "cached": getattr(vm, "cached", 0),
                    "swapTotal": sw.total, "swapUsed": sw.used},
            "disk": {"read": d_r, "write": d_w, "root": root},
            "net": {"rx": n_rx, "tx": n_tx},
            "gpu": gpu(), "uptime": time.time() - psutil.boot_time(), "procs": procs,
        }, separators=(",", ":")), flush=True)
    except BrokenPipeError:
        sys.exit(0)
    time.sleep(max(0.05, INTERVAL - (time.time() - t0)))
