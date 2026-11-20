import QtQuick
import qs
import qs.desktop

// Botón de la barra de opciones: ícono + etiqueta + tecla. Deshabilitado (con punto de aviso) si falta el programa.
Item {
  id: b
  property string icon: ""
  property string label: ""
  property string key: ""
  property string hint: ""
  property bool available: true
  property bool primary: false
  signal activated()
  signal hoverChanged(bool over)

  implicitWidth: row.implicitWidth + 20
  implicitHeight: 40

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusSmall
    color: !b.available ? "transparent"
         : ma.pressed ? Qt.alpha(Theme.accent, 0.34)
         : b.primary ? Qt.alpha(Theme.accent, ma.containsMouse ? 0.30 : 0.20)
         : ma.containsMouse ? Theme.hover : "transparent"
    border.width: b.primary && b.available ? 1 : 0
    border.color: Qt.alpha(Theme.accent, 0.55)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 7
    opacity: b.available ? 1 : 0.42
    Icon {
      anchors.verticalCenter: parent.verticalCenter
      name: b.icon
      fill: b.primary ? 1 : 0
      color: b.primary ? Theme.accent : Theme.foreground
      font.pixelSize: 20
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: b.label
      color: Theme.foreground
      font.family: Theme.fontSans
      font.pixelSize: 13
      font.weight: Font.Medium
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(18, kt.implicitWidth + 10); height: 18; radius: 6
      color: Qt.alpha(Theme.foreground, 0.08)
      border.width: 1; border.color: Qt.alpha(Theme.foreground, 0.14)
      Text { id: kt; anchors.centerIn: parent; text: b.key; color: Theme.muted; font.family: Theme.fontSans; font.pixelSize: 10; font.weight: Font.DemiBold }
    }
  }

  // punto de aviso: falta el programa
  Rectangle {
    visible: !b.available
    width: 7; height: 7; radius: 4
    color: Theme.yellow
    anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 5 }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: b.hoverChanged(containsMouse)
    onClicked: b.activated()
  }
}
