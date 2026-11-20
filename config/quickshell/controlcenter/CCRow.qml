import QtQuick
import QtQuick.Layouts
import qs
import qs.desktop

// Fila de ajuste: etiqueta + descripción a la izquierda, control a la derecha (hijos).
// `modified` marca con un punto de acento que el valor difiere de settings.lua.
Item {
  id: r
  property string label: ""
  property string desc: ""
  property string icon: ""
  property bool modified: false
  property bool last: false
  default property alias control: ctl.data
  property int controlWidth: 0

  Layout.fillWidth: true
  implicitHeight: Math.max(58, inner.implicitHeight + 20)

  Rectangle {
    visible: !r.last
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18 }
    height: 1
    color: Theme.hairline
  }

  RowLayout {
    id: inner
    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 18; rightMargin: 18 }
    spacing: 14
    Icon {
      visible: r.icon !== ""
      name: r.icon
      font.pixelSize: 21
      color: DeskTheme.textMuted
      Layout.alignment: Qt.AlignVCenter
    }
    ColumnLayout {
      Layout.fillWidth: true
      Layout.maximumWidth: 100000   // si no, el ancho máximo sería el del título y el control quedaría pegado a él
      Layout.alignment: Qt.AlignVCenter
      spacing: 2
      RowLayout {
        spacing: 8
        Text {
          text: r.label
          color: Theme.foreground
          font.family: Theme.fontSans
          font.pixelSize: 14
          font.weight: Font.Medium
        }
        Rectangle {
          visible: r.modified
          width: 7; height: 7; radius: 4
          color: Theme.accent
        }
      }
      Text {
        visible: r.desc !== ""
        text: r.desc
        color: DeskTheme.textFaint
        font.family: Theme.fontSans
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }
    RowLayout {
      id: ctl
      Layout.alignment: Qt.AlignVCenter
      Layout.fillWidth: false     // un layout anidado con hijos fillWidth se estiraría solo
      Layout.preferredWidth: r.controlWidth > 0 ? r.controlWidth : implicitWidth
      Layout.maximumWidth: r.controlWidth > 0 ? r.controlWidth : 10000
      spacing: 8
    }
  }
}
