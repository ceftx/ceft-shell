import QtQuick
import QtQuick.Effects

// Imagen recortada en círculo (el clip de un Rectangle no redondea a sus hijos).
Item {
  id: c
  property string source: ""
  property int px: 128                 // tamaño de decodificación
  readonly property bool ready: img.status === Image.Ready
  Image {
    id: img
    anchors.fill: parent
    source: c.source
    sourceSize.width: c.px; sourceSize.height: c.px
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false
    visible: false
    layer.enabled: true
  }
  Rectangle { id: mask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
  MultiEffect {
    anchors.fill: parent
    source: img
    maskEnabled: true
    maskSource: mask
    opacity: c.ready ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200 } }
  }
}
