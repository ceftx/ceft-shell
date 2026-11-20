pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Modo juego (lo implementa `ceft-shell gamemode`; estado = existe $XDG_RUNTIME_DIR/ceft-gamemode).
// La UI lee el archivo cada pocos segundos (así SUPER+G también se refleja) y delega el cambio al CLI.
Singleton {
  id: root
  readonly property string cli: Quickshell.env("CEFT_SHELL_CLI") || (Quickshell.env("HOME") + "/.local/bin/ceft-shell")   // CEFT_SHELL_CLI: solo para pruebas
  property bool on: false
  property bool busy: false
  property string error: ""

  function refresh() { if (!check.running) check.running = true }
  function toggle() { set(!on) }
  function set(v) {
    if (busy) return
    busy = true; error = ""
    cmd.command = [cli, "gamemode", v ? "on" : "off"]
    cmd.want = v
    cmd.running = true
  }

  Process {
    id: check
    command: ["sh", "-c", "test -e \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ceft-gamemode\" && echo 1 || echo 0"]
    stdout: StdioCollector { onStreamFinished: if (!root.busy) root.on = text.trim() === "1" }
  }
  Process {
    id: cmd
    property bool want: false
    stdout: StdioCollector {}
    stderr: StdioCollector { id: errOut }
    onExited: (code) => {
      root.busy = false
      if (code !== 0) root.error = (errOut.text.trim().split("\n").pop()) || "ceft-shell gamemode falló"
      root.refresh()
    }
  }
  Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  // qs ipc call gamemode toggle|on|off
  IpcHandler {
    target: "gamemode"
    function toggle(): void { root.toggle() }
    function on(): void { root.set(true) }
    function off(): void { root.set(false) }
  }
}
