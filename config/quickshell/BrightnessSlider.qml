import QtQuick
import QtQuick.Layouts

// [☀] ━━━━●──── 70%   Brillo del monitor (oculto si `ceft-shell brightness` no responde).
RowLayout {
  id: root
  visible: Brightness.available
  Layout.fillWidth: true
  spacing: 8
  readonly property real frac: Brightness.value / 100

  Text {
    text: Theme.sym("brightness_medium")
    color: Theme.foreground
    font.family: Theme.iconFont; font.pixelSize: 20
    Layout.preferredWidth: 20
    horizontalAlignment: Text.AlignHCenter
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: 3
    Text {
      text: "Brillo · " + (Brightness.method === "ddc" ? "monitor (DDC/CI)" : Brightness.method === "backlight" ? "pantalla" : "monitor")
      elide: Text.ElideRight; Layout.fillWidth: true
      color: Theme.dim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize
    }
    Item {
      Layout.fillWidth: true
      implicitHeight: 14
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 6; radius: 3
        color: Qt.alpha(Theme.foreground, 0.12)
        Rectangle {
          width: parent.width * root.frac; height: parent.height; radius: 3
          color: Theme.accent
          Behavior on width { NumberAnimation { duration: 90 } }
        }
      }
      Rectangle {
        x: (parent.width - width) * root.frac
        anchors.verticalCenter: parent.verticalCenter
        width: area.pressed ? 16 : 12; height: width; radius: width / 2
        color: Theme.foreground
        Behavior on width { NumberAnimation { duration: 100 } }
      }
      MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => Brightness.set(mouse.x / width * 100)
        onPositionChanged: mouse => { if (pressed) Brightness.set(mouse.x / width * 100) }
        onWheel: wheel => Brightness.set(Brightness.value + (wheel.angleDelta.y > 0 ? 5 : -5))
      }
    }
  }
  Text {
    text: Brightness.value + "%"
    color: Theme.foreground; font.family: Theme.font; font.pixelSize: Theme.fontSize
    horizontalAlignment: Text.AlignRight
    Layout.preferredWidth: 36
  }
}
