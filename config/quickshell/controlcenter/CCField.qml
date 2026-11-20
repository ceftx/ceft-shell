import QtQuick
import qs
import qs.desktop

// Campo de texto de una línea. Enter -> accepted.
Rectangle {
  id: f
  property alias text: input.text
  property string placeholder: ""
  property string icon: ""
  property alias input: input
  property alias readOnly: input.readOnly
  signal accepted()
  signal edited()

  implicitHeight: 38
  implicitWidth: 220
  radius: height / 2
  color: input.activeFocus ? Qt.alpha(Theme.foreground, 0.10) : DeskTheme.tile
  border.width: 1
  border.color: input.activeFocus ? Qt.alpha(Theme.accent, 0.7) : Qt.alpha(Theme.foreground, 0.08)
  Behavior on color { ColorAnimation { duration: Theme.animFast } }
  Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

  Icon {
    id: ic
    visible: f.icon !== ""
    name: f.icon
    font.pixelSize: 18
    color: DeskTheme.textFaint
    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
  }
  TextInput {
    id: input
    anchors {
      left: ic.visible ? ic.right : parent.left; leftMargin: ic.visible ? 8 : 16
      right: parent.right; rightMargin: 14
      verticalCenter: parent.verticalCenter
    }
    clip: true
    color: Theme.foreground
    selectionColor: Theme.accent
    selectedTextColor: Theme.background
    font.family: Theme.fontSans
    font.pixelSize: 14
    selectByMouse: true
    onAccepted: f.accepted()
    onTextEdited: f.edited()
    Text {
      visible: input.text === ""
      text: f.placeholder
      color: DeskTheme.textFaint
      font: input.font
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
