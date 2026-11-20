pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Brillo vía `ceft-shell brightness` (DDC/CI o backlight). Si el comando falla, `available` = false y la UI oculta el slider.
// Las escrituras se agrupan: mientras una corre, solo se recuerda el último valor pedido.
Singleton {
  id: root
  readonly property string cli: Quickshell.env("CEFT_SHELL_CLI") || (Quickshell.env("HOME") + "/.local/bin/ceft-shell")   // CEFT_SHELL_CLI: solo para pruebas
  property bool available: false
  property int value: 50
  property string method: ""
  property int pending: -1

  function refresh() { if (!getter.running) getter.running = true }
  function set(v) {
    value = Math.max(0, Math.min(100, Math.round(v)))
    pending = value
    flush.restart()
  }

  Timer { id: flush; interval: 120; onTriggered: root.send() }
  function send() {
    if (setter.running || pending < 0) return
    setter.command = [cli, "brightness", "set", String(pending)]
    pending = -1
    setter.running = true
  }

  Process {
    id: getter
    command: [root.cli, "brightness", "get", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text)
          if (typeof j.value === "number" && root.pending < 0 && !setter.running) { root.value = Math.round(j.value * 100 / (j.max || 100)); root.method = j.method || ""; root.available = true }
          else if (typeof j.value !== "number") root.available = false
        } catch (e) { root.available = false }
      }
    }
    onExited: (code) => { if (code !== 0) root.available = false }
  }
  Process {
    id: setter
    onExited: (code) => {
      if (code !== 0) root.available = false
      else if (root.pending >= 0) root.send()
    }
  }

  Component.onCompleted: refresh()

  // qs ipc call brightness set 0-100
  IpcHandler {
    target: "brightness"
    function set(v: int): void { root.set(v) }
    function refresh(): void { root.refresh() }
  }
}
