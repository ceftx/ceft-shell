import QtQuick
import qs
import qs.desktop

// Módulo de una zona de la barra: ícono + nombre + × para quitar.
// Al seleccionarlo aparecen ‹ › para reordenarlo dentro de su zona.
Rectangle {
  id: c
  property string label: ""
  property string icon: ""
  property bool selected: false
  property bool canLeft: true
  property bool canRight: true
  signal clicked()
  signal removed()
  signal moved(int dir)

  implicitHeight: 32
  implicitWidth: row.implicitWidth + 16
  Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
  radius: height / 2
  color: selected ? Theme.accentContainer : (ma.containsMouse ? DeskTheme.tileHover : Qt.alpha(Theme.foreground, 0.10))
  border.width: 1
  border.color: selected ? Qt.alpha(Theme.accent, 0.7) : Qt.alpha(Theme.foreground, 0.08)
  Behavior on color { ColorAnimation { duration: Theme.animFast } }
  scale: ma.pressed ? 0.97 : 1
  Behavior on scale { NumberAnimation { duration: 90 } }

  MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.clicked() }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6

    Rectangle {
      visible: c.selected
      width: 22; height: 22; radius: 11
      anchors.verticalCenter: parent.verticalCenter
      opacity: c.canLeft ? 1 : 0.3
      color: lma.containsMouse && c.canLeft ? Qt.alpha(Theme.accent, 0.35) : "transparent"
      Icon { anchors.centerIn: parent; name: "chevron_left"; font.pixelSize: 18; color: Theme.accent }
      MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (c.canLeft) c.moved(-1) }
    }
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
    Rectangle {
      visible: c.selected
      width: 22; height: 22; radius: 11
      anchors.verticalCenter: parent.verticalCenter
      opacity: c.canRight ? 1 : 0.3
      color: rma.containsMouse && c.canRight ? Qt.alpha(Theme.accent, 0.35) : "transparent"
      Icon { anchors.centerIn: parent; name: "chevron_right"; font.pixelSize: 18; color: Theme.accent }
      MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (c.canRight) c.moved(1) }
    }
    Rectangle {
      width: 22; height: 22; radius: 11
      anchors.verticalCenter: parent.verticalCenter
      color: xma.containsMouse ? Qt.alpha(Theme.active, 0.30) : "transparent"
      Behavior on color { ColorAnimation { duration: Theme.animFast } }
      Icon { anchors.centerIn: parent; name: "close"; font.pixelSize: 16; color: xma.containsMouse ? Theme.active : DeskTheme.textMuted }
      MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.removed() }
    }
  }
}
