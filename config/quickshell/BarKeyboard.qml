import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Módulo "keyboardLayout": distribución activa (hyprctl devices). Click: siguiente (hyprctl switchxkblayout).
Item {
  id: root
  property bool vertical: false
  property string code: ""
  implicitWidth: code !== "" ? label.implicitWidth : 0
  implicitHeight: vertical ? (code !== "" ? label.implicitHeight : 0) : Theme.barH - 12

  function refresh() { if (!proc.running) proc.running = true }

  Process {
    id: proc
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const kbs = JSON.parse(text).keyboards
          const kb = kbs.find(k => k.main) ?? kbs[0]
          if (!kb) return
          const layouts = String(kb.layout).split(",")
          root.code = (layouts[kb.active_layout_index] ?? layouts[0] ?? "").toUpperCase()
        } catch (e) {}
      }
    }
  }
  Component.onCompleted: refresh()
  Connections {
    target: Hyprland
    function onRawEvent(ev) { if (ev.name === "activelayout") root.refresh() }
  }

  Rectangle {
    anchors.centerIn: parent
    width: parent.width + (root.vertical ? 4 : 16); height: parent.height + (root.vertical ? 4 : -4); radius: height / 2
    color: area.containsMouse ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
  }
  Grid {
    id: label
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 2
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    spacing: root.vertical ? 0 : 4
    Text {
      text: Theme.sym("keyboard"); color: Theme.muted
      font.family: Theme.iconFont; font.pixelSize: 19
    }
    Text {
      text: root.code; color: Theme.foreground
      font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true
    }
  }
  MouseArea {
    id: area
    anchors.fill: parent; anchors.margins: -4
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: { Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]); root.refresh() }
  }
}
