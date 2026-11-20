import QtQuick
import qs

// Tecla en miniatura (hints de teclado)
Rectangle {
  id: k
  property alias text: t.text
  property bool strong: false
  implicitWidth: Math.max(22, t.implicitWidth + 12)
  implicitHeight: 22
  radius: 7
  color: Qt.alpha(Theme.foreground, strong ? 0.14 : 0.08)
  border.width: 1
  border.color: Qt.alpha(Theme.foreground, strong ? 0.22 : 0.13)
  Text {
    id: t
    anchors.centerIn: parent
    color: Theme.foreground
    font.family: Theme.fontSans
    font.pixelSize: 11
    font.weight: Font.DemiBold
  }
}
