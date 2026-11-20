pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// CPU / RAM / GPU NVIDIA en streaming desde scripts/desk-stats.sh (un solo proceso, compartido por todos los monitores)
Singleton {
  id: root
  property int cpu: 0
  property int ram: 0
  property real ramUsed: 0
  property real ramTotal: 0
  property bool hasGpu: false
  property int gpu: 0
  property int gpuTemp: 0
  property int vram: 0

  Process {
    running: true
    command: ["bash", Quickshell.shellDir + "/scripts/desk-stats.sh", "2"]
    stdout: SplitParser {
      onRead: line => {
        const p = line.split(" ")
        if (p[0] === "cpu") root.cpu = parseInt(p[1])
        else if (p[0] === "ram") { root.ram = parseInt(p[1]); root.ramUsed = parseFloat(p[2]); root.ramTotal = parseFloat(p[3]) }
        else if (p[0] === "gpu") { root.hasGpu = true; root.gpu = parseInt(p[1]); root.gpuTemp = parseInt(p[2]); root.vram = parseInt(p[3]) }
      }
    }
  }
}
