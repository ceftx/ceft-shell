import QtQuick
import qs

// Botón de ícono circular o píldora (con texto). Hover/press con transición suave.
Rectangle {
  id: btn
  property string icon: ""
  property string label: ""
  property bool primary: false
  property int size: 40
  property real iconFill: 0
  property int iconSize: 20
  signal clicked()

  implicitHeight: size
  implicitWidth: label ? row.implicitWidth + 28 : size
  radius: height / 2
  color: primary ? (ma.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
                 : (ma.containsMouse ? DeskTheme.tileHover : DeskTheme.tile)
  Behavior on color { ColorAnimation { duration: Theme.animFast } }
  scale: ma.pressed ? 0.94 : 1
  Behavior on scale { NumberAnimation { duration: 100 } }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6
    Icon {
      visible: btn.icon !== ""
      name: btn.icon
      fill: btn.iconFill
      font.pixelSize: btn.iconSize
      color: btn.primary ? DeskTheme.onAccent : DeskTheme.text
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      visible: btn.label !== ""
      text: btn.label
      font.family: DeskTheme.sans
      font.pixelSize: 14
      font.weight: Font.Medium
      color: btn.primary ? DeskTheme.onAccent : DeskTheme.text
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
