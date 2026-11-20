import Quickshell
import Quickshell.Io
import QtQuick

// Indicador "● 00:42" mientras se graba la pantalla (como Omarchy). Click = parar.
// El script ~/.config/hypr/scripts/screenrecord avisa con: qs ipc call recorder started|stopped
BarText {
  id: root
  property bool vertical: false
  property bool recording: false
  property real startedAt: 0
  property int elapsed: 0

  function mmss(s) { return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0") }

  visible: recording
  symbol: true; filled: true
  text: Theme.sym("fiber_manual_record")
  color: Theme.active
  rightPadding: vertical ? 0 : recTime.implicitWidth + 4
  bottomPadding: vertical ? recTime.implicitHeight + 1 : 0
  opacity: blink.on ? 1 : 0.55

  Text {
    id: recTime
    anchors { right: vertical ? undefined : parent.right; horizontalCenter: vertical ? parent.horizontalCenter : undefined; bottom: vertical ? parent.bottom : undefined; verticalCenter: vertical ? undefined : parent.verticalCenter }
    text: root.mmss(root.elapsed)
    color: Theme.active
    font.family: Theme.font; font.pixelSize: vertical ? Theme.fontSmall - 1 : Theme.fontSmall + 1; font.bold: true
  }

  onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/screenrecord"])

  IpcHandler {
    target: "recorder"
    function started(): void { root.recording = true; root.startedAt = Date.now(); root.elapsed = 0 }
    function stopped(): void { root.recording = false }
  }

  Timer {
    id: blink
    property bool on: true
    interval: 1000; repeat: true; running: root.recording
    onTriggered: { on = !on; root.elapsed = Math.round((Date.now() - root.startedAt) / 1000) }
  }

  // Al (re)arrancar la barra, detecta si ya había una grabación en curso
  Process {
    running: true
    command: ["sh", "-c", "f=${XDG_RUNTIME_DIR:-/tmp}/screenrecord.state; [ -f \"$f\" ] && read p _ < \"$f\" && kill -0 \"$p\" 2>/dev/null && echo yes"]
    stdout: StdioCollector { onStreamFinished: if (text.trim() === "yes") { root.recording = true; root.startedAt = Date.now() } }
  }
}
