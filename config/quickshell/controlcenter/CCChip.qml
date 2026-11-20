import QtQuick
import qs
import qs.desktop

// Opción seleccionable (píldora). Seleccionada = contenedor de acento.
Rectangle {
  id: c
  property string label: ""
  property string icon: ""
  property bool selected: false
  signal clicked()

  implicitHeight: 32
  implicitWidth: row.implicitWidth + 28
  radius: height / 2
  color: selected ? Theme.accentContainer : (ma.containsMouse ? DeskTheme.tileHover : DeskTheme.tile)
  border.width: 1
  border.color: selected ? Qt.alpha(Theme.accent, 0.55) : Qt.alpha(Theme.foreground, 0.08)
  Behavior on color { ColorAnimation { duration: Theme.animFast } }
  Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
  scale: ma.pressed ? 0.96 : 1
  Behavior on scale { NumberAnimation { duration: 90 } }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6
    Icon {
      visible: c.icon !== ""
      name: c.icon
      font.pixelSize: 17
      fill: c.selected ? 1 : 0
      color: c.selected ? Theme.accent : DeskTheme.textMuted
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: c.label
      color: c.selected ? Theme.foreground : DeskTheme.textMuted
      font.family: Theme.fontSans
      font.pixelSize: 13
      font.weight: c.selected ? Font.DemiBold : Font.Medium
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.clicked() }
}
