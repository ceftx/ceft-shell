import Quickshell
import Quickshell.Io
import QtQuick

// Módulo "updates": paquetes pendientes (`checkupdates`, cada 60 min). Oculto si hay 0 o no existe checkupdates.
// Click: abre kitty con `paru -Syu`. Click derecho: vuelve a comprobar.
Item {
  id: root
  property bool vertical: false
  property int count: 0
  implicitWidth: count > 0 ? row.implicitWidth : 0
  implicitHeight: vertical ? (count > 0 ? row.implicitHeight : 0) : Theme.barH - 12

  function check() { if (!proc.running) proc.running = true }

  Process {
    id: proc
    command: ["sh", "-c", "command -v checkupdates >/dev/null 2>&1 || { echo 0; exit 0; }; checkupdates 2>/dev/null | wc -l"]
    stdout: StdioCollector { onStreamFinished: root.count = parseInt(text.trim()) || 0 }
  }
  Timer { interval: 3600000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.check() }

  Rectangle {
    anchors.centerIn: parent
    width: parent.width + 12; height: parent.height + (root.vertical ? 4 : -4); radius: height / 2
    color: area.containsMouse ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
  }
  Grid {
    id: row
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 2
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    spacing: root.vertical ? 0 : 3
    Text {
      text: Theme.sym("system_update"); color: Theme.yellow
      font.family: Theme.iconFont; font.pixelSize: 19
    }
    Text {
      text: root.count; color: Theme.foreground
      font.family: Theme.font; font.pixelSize: Theme.fontSmall + 1; font.bold: true
    }
  }
  MouseArea {
    id: area
    anchors.fill: parent; anchors.margins: -4
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) root.check()
      else Quickshell.execDetached([Theme.terminal, "-e", "paru", "-Syu"])
    }
  }
}
