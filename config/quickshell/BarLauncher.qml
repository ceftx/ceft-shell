import Quickshell
import QtQuick

// Módulo "launcher": logo de Arch circular; click abre el launcher propio.
Item {
  property bool vertical: false
  implicitWidth: Theme.barH - 12
  implicitHeight: Theme.barH - 12

  BarText {
    anchors.centerIn: parent
    text: ""   // logo Arch
    font.family: Theme.font
    font.pixelSize: 17
    color: Theme.accent
    pill: false
    onClicked: Quickshell.execDetached(["sh", "-c", "qs ipc call launcher toggle"])
  }
  Rectangle {
    anchors.fill: parent; radius: width / 2; color: "transparent"
    border.width: 1; border.color: Theme.accent
    opacity: logoHover.hovered ? 0.55 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    HoverHandler { id: logoHover }
  }
}
