import QtQuick

// Botón píldora de los diálogos: tonal | primary | danger.
Rectangle {
  id: b
  property string text: ""
  property bool primary: false
  property bool danger: false
  signal clicked()
  implicitHeight: 36
  implicitWidth: label.implicitWidth + 32
  radius: height / 2
  color: {
    const hov = ma.containsMouse
    if (primary) return hov ? Qt.lighter(Theme.accent, 1.12) : Theme.accent
    if (danger) return Qt.alpha(Theme.active, hov ? 0.32 : 0.18)
    return Qt.alpha(Theme.foreground, hov ? 0.16 : 0.09)
  }
  Behavior on color { ColorAnimation { duration: Theme.animFast } }
  scale: ma.pressed ? 0.95 : 1
  Behavior on scale { NumberAnimation { duration: 100 } }
  Text {
    id: label
    anchors.centerIn: parent
    text: b.text
    color: b.primary ? Theme.background : (b.danger ? Theme.active : Theme.foreground)
    font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold
  }
  MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
