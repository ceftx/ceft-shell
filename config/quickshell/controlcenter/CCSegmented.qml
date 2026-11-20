import QtQuick
import qs
import qs.desktop

// Botones segmentados (una sola opción activa), como "Posición" y "Estilo" de la referencia.
// options: [{ v: valor, l: "texto", icon: "nombre" }]. Emite picked(v).
Rectangle {
  id: s
  property var options: []
  property var value
  signal picked(var v)

  implicitHeight: 34
  implicitWidth: row.implicitWidth + 6
  radius: height / 2
  color: Qt.alpha(Theme.foreground, 0.07)
  border.width: 1
  border.color: Qt.alpha(Theme.foreground, 0.08)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 2
    Repeater {
      model: s.options
      Rectangle {
        id: seg
        required property var modelData
        readonly property bool on: s.value === modelData.v
        height: 28
        width: inner.implicitWidth + 24
        radius: 14
        color: on ? Theme.accentContainer : (ma.containsMouse ? Qt.alpha(Theme.foreground, 0.08) : "transparent")
        border.width: on ? 1 : 0
        border.color: Qt.alpha(Theme.accent, 0.55)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        scale: ma.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Row {
          id: inner
          anchors.centerIn: parent
          spacing: 6
          Icon {
            visible: (seg.modelData.icon ?? "") !== ""
            name: seg.modelData.icon ?? ""
            font.pixelSize: 16
            fill: seg.on ? 1 : 0
            color: seg.on ? Theme.accent : DeskTheme.textMuted
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: seg.modelData.l
            color: seg.on ? Theme.foreground : DeskTheme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 13
            font.weight: seg.on ? Font.DemiBold : Font.Medium
            anchors.verticalCenter: parent.verticalCenter
          }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: s.picked(seg.modelData.v) }
      }
    }
  }
}
