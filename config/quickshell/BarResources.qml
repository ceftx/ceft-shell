import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Módulo "resources": uso de IA (Claude Code) y, opcional (bar.json resources.showSystem), CPU/RAM.
// Barra vertical: ícono de IA con el % de sesión debajo (número compacto) y CPU/RAM en columna.
GridLayout {
  id: root
  required property var barWindow
  property bool vertical: false
  columns: vertical ? 1 : 1000
  rowSpacing: 8; columnSpacing: 12

  AgentUsage { barWindow: root.barWindow; vertical: root.vertical }

  // CPU / RAM (solo si se pide: añade un proceso ligero cada 3 s)
  Loader {
    active: BarConfig.showSystemStats
    visible: active
    sourceComponent: Grid {
      id: sys
      columns: root.vertical ? 1 : 2
      horizontalItemAlignment: Grid.AlignHCenter
      property real cpu: 0
      property real mem: 0
      property var prev: null
      spacing: root.vertical ? 6 : 10

      Process {
        id: stat
        command: ["sh", "-c", "head -1 /proc/stat; awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print t, a}' /proc/meminfo"]
        stdout: StdioCollector {
          onStreamFinished: {
            const lines = text.trim().split("\n")
            if (lines.length < 2) return
            const f = lines[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = f[3] + (f[4] || 0), total = f.reduce((a, b) => a + b, 0)
            if (sys.prev) {
              const dt = total - sys.prev.total, di = idle - sys.prev.idle
              if (dt > 0) sys.cpu = Math.round(100 * (dt - di) / dt)
            }
            sys.prev = { idle: idle, total: total }
            const m = lines[1].split(" ").map(Number)
            if (m[0] > 0) sys.mem = Math.round(100 * (m[0] - m[1]) / m[0])
          }
        }
      }
      Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!stat.running) stat.running = true }

      Repeater {
        model: [{ s: "speed", v: sys.cpu }, { s: "memory", v: sys.mem }]
        Grid {
          required property var modelData
          columns: root.vertical ? 1 : 2
          horizontalItemAlignment: Grid.AlignHCenter
          verticalItemAlignment: Grid.AlignVCenter
          spacing: root.vertical ? 0 : 3
          Text {
            text: Theme.sym(modelData.s); color: Theme.accent
            font.family: Theme.iconFont; font.pixelSize: 17
          }
          Text {
            text: modelData.v + "%"; color: Theme.foreground
            font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1
          }
        }
      }
    }
  }
}
