import Quickshell
import QtQuick

// Módulo "utilButtons": captura de región · selector de color · Centro de control.
Grid {
  property bool vertical: false
  columns: vertical ? 1 : 3
  horizontalItemAlignment: Grid.AlignHCenter
  verticalItemAlignment: Grid.AlignVCenter
  spacing: 2

  Repeater {
    model: [
      { s: "crop", cmd: ["sh", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/screenshot region edit"] },
      { s: "colorize", cmd: ["hyprpicker", "-a"] },
      { s: "tune", cmd: ["qs", "ipc", "call", "controlcenter", "toggle"] }
    ]
    BarText {
      required property var modelData
      symbol: true
      text: Theme.sym(modelData.s)
      onClicked: Quickshell.execDetached(modelData.cmd)
    }
  }
}
