import QtQuick
import qs

// Interruptor: la bolita rebota al cambiar.
Item {
  id: sw
  property bool checked: false
  signal toggled(bool value)
  implicitWidth: 46
  implicitHeight: 26

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: sw.checked ? Theme.accent : Qt.alpha(Theme.foreground, ma.containsMouse ? 0.22 : 0.15)
    border.width: sw.checked ? 0 : 1
    border.color: Qt.alpha(Theme.foreground, 0.22)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
  }
  Rectangle {
    id: knob
    width: ma.pressed ? 22 : 18
    height: 18
    radius: 9
    anchors.verticalCenter: parent.verticalCenter
    x: sw.checked ? sw.width - width - 4 : 4
    color: sw.checked ? Theme.background : Qt.alpha(Theme.foreground, 0.85)
    Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
    Behavior on width { NumberAnimation { duration: 90 } }
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
  }
  MouseArea {
    id: ma
    anchors.fill: parent
    anchors.margins: -4
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: sw.toggled(!sw.checked)
  }
}
