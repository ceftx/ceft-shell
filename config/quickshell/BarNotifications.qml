import Quickshell
import QtQuick
import qs.services

// Módulo "notifications": campana con contador de no leídas (punto vacío si hay no molestar).
// Click: panel lateral (qs ipc call sidebar toggle) · click derecho: alterna No molestar.
Item {
  id: root
  property bool vertical: false
  implicitWidth: Theme.barH - 12 + 6
  implicitHeight: Theme.barH - 12

  BarText {
    id: bell
    anchors.centerIn: parent
    symbol: true
    filled: Notifs.unread > 0 && !Notifs.dnd
    text: String.fromCodePoint(Notifs.dnd ? 0xe7f6 : 0xe7f4)   // notifications_off | notifications
    color: Notifs.dnd ? Theme.muted : Theme.foreground
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) Notifs.setDnd(!Notifs.dnd)
      else Quickshell.execDetached(["qs", "ipc", "call", "sidebar", "toggle"])
    }
  }

  // Contador
  Rectangle {
    id: badge
    readonly property bool on: Notifs.unread > 0
    anchors { left: bell.horizontalCenter; leftMargin: 2; bottom: bell.verticalCenter; bottomMargin: 2 }
    height: 15; width: Math.max(15, num.implicitWidth + 7); radius: 8
    color: Notifs.dnd ? Qt.alpha(Theme.foreground, 0.35) : Theme.active
    scale: on ? 1 : 0
    opacity: on ? 1 : 0
    Behavior on scale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Text {
      id: num
      anchors.centerIn: parent
      text: Notifs.unread > 99 ? "99+" : Notifs.unread
      color: Notifs.dnd ? Theme.foreground : Theme.background
      font.family: Theme.fontSans; font.pixelSize: 10; font.weight: Font.Bold
    }
  }
}
