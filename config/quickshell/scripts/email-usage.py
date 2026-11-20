#!/usr/bin/env python3
"""Envía por email el consumo de tokens de Claude (todas las sesiones o por cuenta).

Configura en ~/.claude/email-usage.env (o edita las variables aquí):
  SMTP_USER=tu@correo.com
  SMTP_PASS=<tu_app_password>   (o mejor: ceft-shell secret set SMTP_PASS, se guarda en el keyring)
  EMAIL_TO=tu@correo.com
  EMAIL_FROM=tu@correo.com
"""
import json
import os
import smtplib
import shutil
import subprocess
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path

ENV_FILE = Path.home() / ".claude" / "email-usage.env"
if ENV_FILE.exists():
    for line in ENV_FILE.read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            os.environ.setdefault(k, v)

SMTP_USER = os.environ.get("SMTP_USER", "")


def keyring_secret(name):
    """Lee un secreto guardado con `ceft-shell secret set <name>` (libsecret); "" si no hay."""
    if not shutil.which("secret-tool"):
        return ""
    try:
        r = subprocess.run(["secret-tool", "lookup", "service", "ceft-shell", "name", name],
                           capture_output=True, text=True, timeout=10)
        return r.stdout.rstrip("\n") if r.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


# Orden: entorno / email-usage.env (método actual) -> keyring (ceft-shell secret set SMTP_PASS)
SMTP_PASS = os.environ.get("SMTP_PASS") or keyring_secret("SMTP_PASS")
EMAIL_TO = os.environ.get("EMAIL_TO", SMTP_USER)
EMAIL_FROM = os.environ.get("EMAIL_FROM", SMTP_USER)


def build_body(usage):
    lines = [
        "📊 Consumo Claude Code · hoy",
        "",
        f"Total tokens hoy: {usage.get('today', {}).get('total', 0):,}",
        f"Entrada: {usage.get('today', {}).get('input', 0):,}",
        f"Salida: {usage.get('today', {}).get('output', 0):,}",
        f"Sesiones activas: {usage.get('sessions', 0)}",
        "",
        "Por sesión:",
    ]
    for s in usage.get("session_details", []):
        proj = s.get("project", "?")
        sid = s.get("sessionId", "?")[:16]
        tok = s.get("tokens", 0)
        lines.append(f"  • {proj} (session: ...{sid}) → {tok:,} tokens")
    lines.extend([
        "",
        f"Últimos 7 días: {usage.get('week', 0):,} tokens",
        f"Actualizado: {usage.get('updated', '?')}",
        "",
        "— Quickshell AgentUsage",
    ])
    return "\n".join(lines)


def send_email(usage_json_path=None):
    import subprocess
    # Obtener datos actuales (o de archivo si se pasa)
    if usage_json_path:
        usage = json.loads(Path(usage_json_path).read_text())
    else:
        result = subprocess.run(
            ["python3", "-I", Path.home() / ".config" / "quickshell" / "scripts" / "agent-usage.py"],
            capture_output=True, text=True
        )
        usage = json.loads(result.stdout) if result.returncode == 0 else {}

    msg = MIMEMultipart()
    msg["From"] = EMAIL_FROM
    msg["To"] = EMAIL_TO
    msg["Subject"] = "📊 Consumo Claude Code · hoy"
    msg.attach(MIMEText(build_body(usage), "plain"))

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(SMTP_USER, SMTP_PASS)
            server.sendmail(EMAIL_FROM, EMAIL_TO, msg.as_string())
        print("✅ Email enviado a", EMAIL_TO)
    except Exception as e:
        print("❌ Error enviando email:", e)


if __name__ == "__main__":
    import sys
    send_email(sys.argv[1] if len(sys.argv) > 1 else None)
