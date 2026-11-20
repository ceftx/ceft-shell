import Quickshell.Io
import QtQuick

// Ejecuta un comando de shell sin bloquear la UI; acumula la salida (stdout+stderr) línea a línea.
Item {
  id: r
  visible: false
  width: 0; height: 0
  property bool running: false
  property bool done: false
  property string output: ""
  property int code: -1
  readonly property bool ok: done && code === 0
  signal finished(int code, string output)

  function run(cmd) {
    if (running) return
    output = ""; code = -1; done = false; running = true
    p.command = ["sh", "-c", cmd + " 2>&1"]
    p.running = true
  }

  function cancel() { if (running) p.running = false }

  Process {
    id: p
    stdout: SplitParser { onRead: line => r.output += line + "\n" }
    onExited: (c) => { r.code = c; settle.restart() }
  }
  // Deja que se vacíen los últimos bytes del pipe antes de dar el resultado.
  Timer {
    id: settle
    interval: 80
    onTriggered: { r.running = false; r.done = true; r.finished(r.code, r.output) }
  }
}
