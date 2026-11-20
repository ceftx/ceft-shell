import QtQuick
import QtQuick.Layouts

// Texto/icono clickeable de la barra, con píldora de hover/activo detrás.
// `symbol: true` → el texto es una ligadura de Material Symbols ("wifi", "volume_up"…).
Text {
  id: root
  signal clicked(var mouse)
  signal scrolled(int delta)
  property string tooltip: ""
  property bool lit: false          // panel abierto / estado activo: deja la píldora encendida
  property bool pill: true          // false: sin píldora (texto suelto dentro de paneles)
  property bool symbol: false       // Material Symbols
  property bool filled: false       // FILL=1 (solo symbol)
  readonly property bool hovered: area.containsMouse
  readonly property bool pressed: area.pressed

  Layout.alignment: Qt.AlignCenter
  color: Theme.foreground
  font.family: symbol ? Theme.iconFont : Theme.fontSans
  font.pixelSize: symbol ? 20 : Theme.fontBase
  verticalAlignment: Text.AlignVCenter
  Behavior on color { ColorAnimation { duration: Theme.animFast } }

  Rectangle {
    z: -1
    visible: root.pill
    anchors.centerIn: parent
    width: Math.max(root.height, root.width + 12)
    height: Math.min(BarConfig.thickness - 12, Math.max(root.height, 28))
    radius: height / 2
    color: root.lit ? Theme.accentContainer : root.hovered ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    anchors.margins: -4
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => root.clicked(mouse)
    onWheel: wheel => root.scrolled(wheel.angleDelta.y)
  }
}
