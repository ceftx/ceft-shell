import QtQuick
import QtQuick.Layouts

// Fila clicable de lista: [icono] título / subtítulo ....... detalle
Rectangle {
  id: root
  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property string detail: ""
  property bool active: false
  property bool busy: false
  signal clicked(var mouse)
  default property alias extra: extraCol.data

  Layout.fillWidth: true
  implicitHeight: col.implicitHeight + 16
  radius: Theme.radiusSmall
  color: active ? Qt.alpha(Theme.accent, 0.16)
       : area.containsMouse ? Theme.hover : "transparent"
  Behavior on color { ColorAnimation { duration: Theme.animFast } }

  ColumnLayout {
    id: col
    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
    spacing: 6
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Text {
        text: root.icon
        color: root.active ? Theme.accent : Theme.foreground
        font.family: Theme.font
        font.pixelSize: Theme.fontBase + 3
        Layout.preferredWidth: 20
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
          text: root.title
          elide: Text.ElideRight
          Layout.fillWidth: true
          color: root.active ? Theme.accent : Theme.foreground
          font.family: Theme.fontSans
          font.pixelSize: Theme.fontBase
          font.bold: root.active
        }
        Text {
          visible: text !== ""
          text: root.busy ? "…" + root.subtitle : root.subtitle
          elide: Text.ElideRight
          Layout.fillWidth: true
          color: Theme.dim
          font.family: Theme.fontSans
          font.pixelSize: Theme.fontSize
        }
      }
      Text {
        text: root.detail
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
      }
    }
    ColumnLayout { id: extraCol; Layout.fillWidth: true; visible: children.length > 0 }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    z: -1
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => root.clicked(mouse)
  }
}
