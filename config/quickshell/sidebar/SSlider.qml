import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Slider de panel: [icono] ━━━●━━ 45%. Click en el icono = mute; arrastrar / rueda = valor.
RowLayout {
  id: root
  property real value: 0            // 0..1
  property bool muted: false
  property bool enabled2: true
  property string icon: "volume_up"
  property string label: ""
  property bool compact: false
  property bool showPct: true
  signal moved(real v)
  signal iconClicked()
  spacing: 12
  Layout.fillWidth: true
  opacity: enabled2 ? 1 : 0.45

  Rectangle {
    Layout.preferredWidth: root.compact ? 30 : 36
    Layout.preferredHeight: width
    radius: width / 2
    color: iconMa.containsMouse ? DeskTheme.tileHover : DeskTheme.tile
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Icon { anchors.centerIn: parent; name: root.icon; fill: root.muted ? 0 : 1; font.pixelSize: root.compact ? 18 : 20; color: root.muted ? DeskTheme.textFaint : Theme.accent }
    MouseArea { id: iconMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: root.enabled2; onClicked: root.iconClicked() }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 2
    Text {
      visible: root.label !== ""
      text: root.label
      Layout.fillWidth: true
      elide: Text.ElideRight
      color: DeskTheme.textMuted
      font.family: Theme.fontSans; font.pixelSize: 12
    }
    Item {
      Layout.fillWidth: true
      implicitHeight: 22
      Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: ma.pressed ? 12 : 10; radius: height / 2
        color: Qt.alpha(Theme.foreground, 0.13)
        Behavior on height { NumberAnimation { duration: 90 } }
        Rectangle {
          width: Math.max(parent.height, parent.width * Math.min(1, root.value)); height: parent.height; radius: height / 2
          color: root.muted ? DeskTheme.textFaint : Theme.accent
          Behavior on width { NumberAnimation { duration: ma.pressed ? 0 : 90 } }
          Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
      }
      MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled2
        cursorShape: Qt.PointingHandCursor
        function at(x) { root.moved(Math.max(0, Math.min(1, x / width))) }
        onPressed: mouse => at(mouse.x)
        onPositionChanged: mouse => { if (pressed) at(mouse.x) }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
      }
    }
  }

  Text {
    visible: root.showPct
    text: Math.round(root.value * 100) + "%"
    Layout.preferredWidth: 38
    horizontalAlignment: Text.AlignRight
    color: root.muted ? DeskTheme.textFaint : DeskTheme.text
    font.family: Theme.fontSans; font.pixelSize: 12; font.weight: Font.Medium
  }
}
