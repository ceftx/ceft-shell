import QtQuick
import QtQuick.Layouts

// Fila "etiqueta ........ [interruptor]"
RowLayout {
  id: root
  property string label
  property bool checked: false
  signal toggled(bool value)
  Layout.fillWidth: true

  Text {
    text: root.label
    color: Theme.foreground
    font.family: Theme.fontSans
    font.pixelSize: Theme.fontBase
  }
  Item { Layout.fillWidth: true }
  Rectangle {
    implicitWidth: 38; implicitHeight: 22; radius: 11
    color: root.checked ? Theme.accent : Qt.alpha(Theme.foreground, 0.12)
    border.color: root.checked ? "transparent" : Theme.glassEdge
    Behavior on color { ColorAnimation { duration: 160 } }
    Rectangle {
      width: 16; height: 16; radius: 8
      anchors.verticalCenter: parent.verticalCenter
      x: root.checked ? parent.width - width - 3 : 3
      color: root.checked ? Theme.background : Theme.dim
      Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggled(!root.checked)
    }
  }
}
