import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Ajuste rápido estilo Android: píldora con icono, título y estado. Encendido = color de acento.
Item {
  id: root
  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property bool checked: false
  property bool busy: false
  property bool warn: false          // estado de atención (ej. killswitch sin VPN)
  property bool detail: false        // muestra un chevron: el clic derecho / chevron abre más
  property bool enabled2: true
  signal clicked()
  signal secondary()

  implicitHeight: 56
  opacity: enabled2 ? 1 : 0.5

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Theme.radiusSmall + 6
    color: root.checked ? (root.warn ? Qt.alpha(Theme.active, 0.30) : Theme.accentContainer)
         : ma.containsMouse ? DeskTheme.tileHover : DeskTheme.tile
    border.width: root.checked ? 1 : 0
    border.color: root.warn ? Qt.alpha(Theme.active, 0.55) : Qt.alpha(Theme.accent, 0.5)
    scale: ma.pressed ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: 90 } }

    RowLayout {
      anchors { fill: parent; leftMargin: 9; rightMargin: root.detail ? 4 : 8 }
      spacing: 9
      Rectangle {
        Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
        color: root.checked ? (root.warn ? Theme.active : Theme.accent) : Qt.alpha(Theme.foreground, 0.10)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Icon {
          anchors.centerIn: parent
          name: root.icon; fill: root.checked ? 1 : 0; font.pixelSize: 20
          color: root.checked ? Theme.background : DeskTheme.text
          opacity: root.busy ? 0.4 : 1
        }
        Icon {   // busy: spinner
          visible: root.busy
          anchors.centerIn: parent; name: "progress_activity"; font.pixelSize: 24
          color: root.checked ? Theme.background : Theme.accent
          RotationAnimator on rotation { running: root.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
          text: root.title
          Layout.fillWidth: true; elide: Text.ElideRight
          color: DeskTheme.text
          font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.DemiBold
        }
        Text {
          visible: root.subtitle !== ""
          text: root.subtitle
          Layout.fillWidth: true; elide: Text.ElideRight
          color: root.checked && root.warn ? Theme.active : DeskTheme.textMuted
          font.family: Theme.fontSans; font.pixelSize: 11
        }
      }
      Item {
        visible: root.detail
        Layout.preferredWidth: 28; Layout.preferredHeight: 28
        Icon { anchors.centerIn: parent; name: "chevron_right"; font.pixelSize: 20; color: DeskTheme.textMuted; opacity: chevMa.containsMouse ? 1 : 0.7 }
        MouseArea { id: chevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.secondary() }
      }
    }
  }
  MouseArea {
    id: ma
    anchors.fill: parent
    anchors.rightMargin: root.detail ? 32 : 0
    hoverEnabled: true
    enabled: root.enabled2
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => { if (mouse.button === Qt.RightButton) root.secondary(); else root.clicked() }
  }
}
