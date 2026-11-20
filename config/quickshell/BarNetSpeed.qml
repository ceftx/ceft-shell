import Quickshell
import Quickshell.Io
import QtQuick

// Módulo "netSpeed": ↓ ↑ de la interfaz de la ruta por defecto (/proc/net/dev), cada 2 s.
Item {
  id: root
  property bool vertical: false
  property real rx: 0
  property real tx: 0
  property real prevRx: -1
  property real prevTx: 0
  property real prevT: 0
  property string dev: ""
  implicitWidth: row.implicitWidth
  implicitHeight: vertical ? row.implicitHeight : Theme.barH - 12

  function fmt(bps) {   // bytes/s → "1.2M" (siempre 5 caracteres, fuente mono)
    let v = bps, u = "B"
    for (const next of ["K", "M", "G"]) { if (v < 1000) break; v /= 1024; u = next }
    const s = v >= 100 || u === "B" ? Math.round(v).toString() : v.toFixed(1)
    return (s + u).padStart(5, " ")
  }

  Process {
    id: proc
    command: ["sh", "-c",
      "d=$(ip route show default 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i==\"dev\"){print $(i+1); exit}}'); " +
      "[ -n \"$d\" ] && awk -v d=\"$d\" '{sub(\":\",\" \")} $1==d{print d, $2, $10}' /proc/net/dev"]
    stdout: StdioCollector {
      onStreamFinished: {
        const p = text.trim().split(" ")
        if (p.length < 3) { root.dev = ""; root.prevRx = -1; return }
        const now = Date.now(), r = Number(p[1]), t = Number(p[2])
        if (root.prevRx >= 0 && p[0] === root.dev && now > root.prevT) {
          const dt = (now - root.prevT) / 1000
          root.rx = Math.max(0, (r - root.prevRx) / dt)
          root.tx = Math.max(0, (t - root.prevTx) / dt)
        }
        root.dev = p[0]; root.prevRx = r; root.prevTx = t; root.prevT = now
      }
    }
  }
  Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!proc.running) proc.running = true }

  Grid {
    id: row
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 2
    horizontalItemAlignment: Grid.AlignHCenter
    spacing: root.vertical ? 4 : 8
    Repeater {
      model: [{ s: "arrow_downward", v: root.rx }, { s: "arrow_upward", v: root.tx }]
      Grid {
        required property var modelData
        columns: root.vertical ? 1 : 2
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: root.vertical ? -3 : 1
        Text {
          text: Theme.sym(modelData.s); color: Theme.accent
          font.family: Theme.iconFont; font.pixelSize: 16
        }
        Text {
          text: root.vertical ? root.fmt(modelData.v).trim() : root.fmt(modelData.v); color: Theme.foreground
          font.family: Theme.font; font.pixelSize: root.vertical ? Theme.fontSmall - 2 : Theme.fontSmall
        }
      }
    }
  }
}
