import QtQuick
import QtQuick.Layouts

// [icono] ━━━━━●──── 45%   (click en icono = mute, arrastrar/rueda = volumen)
RowLayout {
  id: root
  property var node: null                 // PwNode con .audio
  property string iconOn: String.fromCodePoint(0xf057e)
  property string iconOff: String.fromCodePoint(0xf0581)
  property string label: ""
  readonly property bool ready: node !== null && node.audio !== null
  readonly property real value: ready ? node.audio.volume : 0
  readonly property bool muted: ready ? node.audio.muted : true
  Layout.fillWidth: true
  spacing: 8

  function set(v) { if (ready) { node.audio.volume = Math.max(0, Math.min(1, v)); if (v > 0) node.audio.muted = false } }

  Text {
    text: root.muted ? root.iconOff : root.iconOn
    color: root.muted ? Theme.dim : Theme.foreground
    font.family: Theme.font
    font.pixelSize: Theme.fontBase + 3
    Layout.preferredWidth: 20
    MouseArea {
      anchors.fill: parent
      anchors.margins: -4
      cursorShape: Qt.PointingHandCursor
      onClicked: if (root.ready) root.node.audio.muted = !root.node.audio.muted
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 3
    Text {
      visible: root.label !== ""
      text: root.label
      elide: Text.ElideRight
      Layout.fillWidth: true
      color: Theme.dim
      font.family: Theme.fontSans
      font.pixelSize: Theme.fontSize
    }
    Item {
      Layout.fillWidth: true
      implicitHeight: 14
      Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 6; radius: 3
        color: Qt.alpha(Theme.foreground, 0.12)
        Rectangle {
          width: parent.width * root.value
          height: parent.height; radius: 3
          color: root.muted ? Theme.dim : Theme.accent
          Behavior on width { NumberAnimation { duration: 90 } }
        }
      }
      Rectangle {
        x: (parent.width - width) * root.value
        anchors.verticalCenter: parent.verticalCenter
        width: sliderArea.pressed ? 16 : 12; height: width; radius: width / 2
        color: root.muted ? Theme.dim : Theme.foreground
        Behavior on width { NumberAnimation { duration: 100 } }
      }
      MouseArea {
        id: sliderArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.set(mouse.x / width)
        onPositionChanged: mouse => { if (pressed) root.set(mouse.x / width) }
        onWheel: wheel => root.set(root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
      }
    }
  }

  Text {
    text: Math.round(root.value * 100) + "%"
    color: root.muted ? Theme.dim : Theme.foreground
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    horizontalAlignment: Text.AlignRight
    Layout.preferredWidth: 36
  }
}
